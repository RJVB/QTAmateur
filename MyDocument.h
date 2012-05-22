//
//  MyDocument.h
//  QTAmateur
//
//  Created by Michael Ash on 5/22/05.
//  Copyright __MyCompanyName__ 2005 . All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import "QTAMovieView.h"
#import "NSATextField.h"

typedef enum {FSRegular, FSSpanning, FSMosaic } FSStyle;

//@class QTMovieView;
@class QTAMovieView;
@class ExportManager;

@interface MyDocument : NSDocument {
	IBOutlet QTAMovieView *movieView;

	QTMovie *movie;
#ifdef SHADOW
	IBOutlet QTAMovieView *movieShadowView;
	QTMovie *movieShadow;
#endif

	BOOL resizesVertically;

	int halfSize, normalSize, doubleSize, maxSize,
		playAllFrames, Loop;

	IBOutlet NSWindow *fullscreenWindow;
	IBOutlet QTAMovieView *fullscreenMovieView;

	IBOutlet NSDrawer		*mDrawer;
	IBOutlet NSTextField	*mCurrentSize;
	IBOutlet NSTextField	*mDuration;
	IBOutlet NSTextField	*mNormalSize;
	IBOutlet NSTextField	*mSourceName;
	IBOutlet NSATextField	*mTimeDisplay;
	IBOutlet NSATextField	*mRateDisplay;

	IBOutlet NSView *exportAccessoryView;
	IBOutlet NSPopUpButton *exportTypePopup;
	IBOutlet NSTextField *exportInfoField;
	ExportManager *exportManager;

	NSTimer *dontSleepTimer;

	ComponentResult callbackResult;

@public
	BOOL inFullscreen;
	int Playing;
	short wasStepped, wasScanned, isProgrammatic;
	NSDrawerState InfoDrawer;
#ifdef DEBUG
	QTTime prevActionTime;
#endif
}

- (void)updateMenus;

- (QTMovie*)getMovie;
- (QTAMovieView*)getView;
- (id)drawer;

- (void)setMovie:(QTMovie *)m;

- (void)toggleInfoDrawer:sender;
- (void)setDurationDisplay;
- (void)setNormalSizeDisplay;
- (void)setCurrentSizeDisplay;
- (void)setSource:(NSString *)name;
- (void)setTimeDisplay;
- (void)setRateDisplay;
- (void)UpdateDrawer;
- (void)gotoTime:sender;

- (void)setOneToOne:sender;
- (void)setHalfSize:sender;
- (void)setDoubleSize:sender;
- (void)setFullscreenSize:sender;
- (void)setHalvedSize:sender;
- (void)setHalvedSizeAll:sender;
- (void)setDoubledSize:sender;
- (void)setDoubledSizeAll:sender;

- (void)setFullscreen:sender;
- (void)doExportSettings:sender;
- (void)exportPopupChanged:sender;

- (void)goPosterFrame:sender;
- (void)goBeginning:sender;
- (void)goPosterFrameAll:sender;
- (void)goBeginningAll:sender;

- (void)setPBAll:sender;
- (void)setAllPBAll:sender;
- (void)setLoop:sender;
- (void)setLoopAll:sender;

- (void)playAll:sender;
- (void)playAllFullScreen:sender;
- (void)stepForwardAll:sender;
- (void)stepBackwardAll:sender;

- (void)makeFullscreenView:(FSStyle)style;
- (void)beginFullscreen:(FSStyle)style;
- (void)endFullscreen;

- (void)disableSleep;
- (void)enableSleep;

- (void) removeMovieCallBack;
- (void) installMovieCallBack;

// delegate functions:
- (BOOL) windowShouldClose:(id)sender;
- (void) windowWillClose:(NSNotification*)notification;

@end
