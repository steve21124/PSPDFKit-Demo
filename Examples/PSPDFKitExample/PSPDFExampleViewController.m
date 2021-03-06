//
//  PSPDFExampleViewController.m
//  PSPDFKitExample
//
//  Copyright 2011 Peter Steinberger. All rights reserved.
//

#import "PSPDFExampleViewController.h"
#import "AppDelegate.h"
#import "PSPDFMagazine.h"
#import "PSPDFSettingsController.h"
#import "PSPDFGridController.h"

@implementation PSPDFExampleViewController

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

- (void)closeModalView {
    [self dismissModalViewControllerAnimated:YES];
}

- (void)optionsButtonPressed:(id)sender {
    if ([self.popoverController.contentViewController isKindOfClass:[PSPDFSettingsController class]]) {
        [self.popoverController dismissPopoverAnimated:YES];
        self.popoverController = nil;
    }else {
        PSPDFSettingsController *cacheSettingsController = [[PSPDFSettingsController alloc] init];
        if (PSIsIpad()) {
            self.popoverController = [[UIPopoverController alloc] initWithContentViewController:cacheSettingsController];
            [self.popoverController presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        }else {
            [self presentModalViewController:cacheSettingsController withCloseButton:YES animated:YES];
        }
    }
}

// Helper for the option pane. You really shouldn't include that in your final app.
// This is just to show what PSPDFKit can do.
- (void)globalVarChanged {
    // set global settings for magazine
    self.magazine.searchEnabled = [PSPDFSettingsController search];
    self.magazine.annotationsEnabled = [PSPDFSettingsController annotations];
    self.magazine.outlineEnabled = [PSPDFSettingsController pdfoutline];
    self.magazine.aspectRatioEqual = [PSPDFSettingsController aspectRatioEqual];
    self.magazine.twoStepRenderingEnabled = [PSPDFSettingsController twoStepRendering];
    
    // set global settings from PSPDFCacheSettingsController
    self.doublePageModeOnFirstPage = [PSPDFSettingsController doublePageModeOnFirstPage];
    self.zoomingSmallDocumentsEnabled = [PSPDFSettingsController zoomingSmallDocumentsEnabled];
    self.scrobbleBarEnabled = [PSPDFSettingsController scrobbleBar];
    self.fitWidth = [PSPDFSettingsController fitWidth];
    //self.pagingEnabled = [PSPDFSettingsController pagingEnabled];
    
    NSUInteger page = [self landscapePage:self.page];
    self.pageMode = [PSPDFSettingsController pageMode];
    self.pageScrolling = [PSPDFSettingsController pageScrolling];
    
    // reload scrollview
    [self reloadDataAndScrollToPage:page];
    
    // update toolbar
    if ([self isViewLoaded]) {
        [self createToolbar];        
        [self updateToolbars];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithDocument:(PSPDFDocument *)magazine {
    if ((self = [super initWithDocument:magazine])) {
        self.delegate = self;
        
        // initally update vars
        [self globalVarChanged];
        
        // register for global var change notifications from PSPDFCacheSettingsController
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(globalVarChanged) name:kGlobalVarChangeNotification object:nil];
        
        // Remains work in progress
        //self.pageTurnEnabled = YES;
        
        // change statusbar setting to your preferred style
        //statusBarStyleSetting_ = PSPDFStatusBarDisable;        
    }    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (PSPDFMagazine *)magazine {
    return (PSPDFMagazine *)self.document;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIViewController

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    /*
    // Example how to customize the double page mode switching. 
    if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation) && !PSIsIpad()) {
        self.pageMode = PSPDFPageModeDouble;
    }else {
        self.pageMode = PSPDFPageModeAutomatic;
    }*/
    
    // toolbar will be recreated, so release popover after rotation (else CoreAnimation crashes on us)
    [self.popoverController dismissPopoverAnimated:YES];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFViewController

- (NSArray *)additionalLeftToolbarButtons {
    UIBarButtonItem *button;
    
    PSPDF_IF_PRE_IOS5(button = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"settings"]      
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(optionsButtonPressed:)];)
    
    // on iOS5, we can finally set the landscapeImagePhone
    PSPDF_IF_IOS5_OR_GREATER(button = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"settings"]
                                                         landscapeImagePhone:[UIImage imageNamed:@"settings_landscape"]
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(optionsButtonPressed:)];)
    
    return [NSArray arrayWithObject:button];
}

- (void)documentButtonPressed {
    [self.navigationController popViewControllerAnimated:NO];
}

- (UIBarButtonItem *)toolbarBackButton {
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:PSIsIpad() ? PSPDFLocalize(@"Documents") : PSPDFLocalize(@"Back")
                                                                   style:UIBarButtonItemStyleBordered
                                                                  target:self
                                                                  action:@selector(documentButtonPressed)];
    return backButton;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFViewControllerDelegate

// time to adjust PSPDFViewController before a PSPDFDocument is displayed
- (void)pdfViewController:(PSPDFViewController *)pdfController willDisplayDocument:(PSPDFDocument *)document {
    pdfController.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"linen_texture_dark"]];
}

// if user tapped within page bounds, this will notify you.
// return YES if this touch was processed by you and need no further checking by PSPDFKit.
- (BOOL)pdfViewController:(PSPDFViewController *)pdfController didTapOnPage:(NSUInteger)page atPoint:(CGPoint)point pageSize:(CGSize)pageSize {
    PSELog(@"Page %@ tapped at %@.", NSStringFromCGSize(pageSize), NSStringFromCGPoint(point));
    
    // touch not used
    return NO;
}

- (void)pdfViewController:(PSPDFViewController *)pdfController didRenderPageView:(PSPDFPageView *)pageView {
    PSELog(@"page %d rendered.", pageView.page);
}

- (BOOL)pdfViewController:(PSPDFViewController *)pdfController didTapOnAnnotation:(PSPDFAnnotation *)annotation page:(NSUInteger)page info:(PSPDFPageInfo *)pageInfo coordinates:(PSPDFPageCoordinates *)pageCoordinates {
    BOOL handled;
    if (annotation.type == PSPDFAnnotationTypeHighlight) {
        [[[UIAlertView alloc] initWithTitle:PSPDFLocalize(@"Tapped highlight!") 
                                    message:annotation.contents
                                   delegate:nil
                          cancelButtonTitle:PSPDFLocalize(@"Dismiss")
                          otherButtonTitles:nil] show];
        handled = YES;
    } else {
        handled = NO;
    }
    
    return handled;
}

@end
