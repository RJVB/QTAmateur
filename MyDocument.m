//
//  MyDocument.m
//  QTAmateur
//
//  Created by Michael Ash on 5/22/05.
//  Copyright __MyCompanyName__ 2005 . All rights reserved.
//

#import "MyDocument.h"

#import <QTKit/QTKit.h>

#import "ExportManager.h"
#import "MAMovieExport.h"

#include <pthread.h>

static pascal Boolean QTActionCallBack( MovieController mc, short action, void* params, long refCon );

@interface MyDocument (Private)

- (NSSize)movieSizeForWindowSize:(NSSize)s;
- (NSSize)windowSizeForMovieSize:(NSSize)s;
- (NSSize)movieUnsizedSize;
- (NSSize)moviePreferredSize;
- (NSSize)movieCurrentSize;
- (void)setMovieSize:(NSSize)size;
- (NSSize)sizeWithMovieAspectFromSize:(NSSize)s;

@end


@implementation MyDocument (Private)

- (NSSize)movieSizeForWindowSize:(NSSize)s
{
	NSWindow *window = [movieView window];
	NSRect windowRect = [window frame];
	windowRect.size = s;
	NSSize newContentSize = [window contentRectForFrameRect:windowRect].size;

	NSSize viewSize = [movieView bounds].size;
	viewSize.height -= [movieView controllerBarHeight];
	NSSize curWindowSize = [[window contentView] bounds].size;

	float dx = curWindowSize.width - viewSize.width;
	float dy = curWindowSize.height - viewSize.height;

	return NSMakeSize(newContentSize.width - dx, newContentSize.height - dy);
}

- (NSSize)windowSizeForMovieSize:(NSSize)s
{
	NSWindow *window = [movieView window];
	NSSize viewSize = [movieView bounds].size;
	viewSize.height -= [movieView controllerBarHeight];
	NSRect contentRect = [[window contentView] bounds];
	NSSize curWindowSize = contentRect.size;

	float dx = curWindowSize.width - viewSize.width;
	float dy = curWindowSize.height - viewSize.height;

#ifdef SHADOW
	contentRect.size = NSMakeSize(s.width + dx, 2 * (s.height + dy));
#else
	contentRect.size = NSMakeSize(s.width + dx, s.height + dy);
#endif

	return [window frameRectForContentRect:contentRect].size;
}

- (NSSize)movieUnsizedSize
{
	return NSMakeSize(300, 0);
}

- (NSSize)moviePreferredSize
{ QTMovie *m= (inFullscreen)? [fullscreenMovieView movie] : [movieView movie];
	NSSize size;
	NSValue *sizeObj = [[m movieAttributes] objectForKey:QTMovieNaturalSizeAttribute];
	if(sizeObj)
		size = [sizeObj sizeValue];
	if(!sizeObj || size.height < 2)
		size = [self movieUnsizedSize];
	return size;
}


- (NSSize)movieCurrentSize
{ QTMovie *m= (inFullscreen)? [fullscreenMovieView movie] : [movieView movie];
	NSSize size;
	NSValue *sizeObj = [[m movieAttributes] objectForKey:QTMovieCurrentSizeAttribute];
	if(sizeObj)
		size = [sizeObj sizeValue];
	if(!sizeObj || size.height < 2)
		size = [self movieUnsizedSize];
	return size;
}

- (void)setMovieSize:(NSSize)size
{ QTMovie *m= (inFullscreen)? [fullscreenMovieView movie] : [movieView movie];
	NSLog( @"setMovieSize %@ to %fx%f", m, size.width, size.height );
	[m setMovieAttributes:[NSDictionary dictionaryWithObject:[NSValue valueWithSize:size] forKey:QTMovieCurrentSizeAttribute]];
}

- (NSSize)sizeWithMovieAspectFromSize:(NSSize)s
{
	NSSize preferredSize = [self moviePreferredSize];
	float aspect = preferredSize.width / preferredSize.height;
	float xx = s.width;
	float yx = s.height * aspect;
	float x = MIN(xx, yx);
	return NSMakeSize(x, x / aspect);
}

@end

typedef struct MyDocList{
	MyDocument *docwin;
	int id, playing;
	struct MyDocList *car, *cdr;
} MyDocList;

MyDocList *DocList= NULL;
int MyDocs= 0;

@implementation MyDocument

- (id)init
{
    self = [super init];
    if (self) {

        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.

    }
    return self;
}

- (void)dealloc
{
	[self removeMovieCallBack];

	[self setMovie:nil];
	[exportManager release];

	[super dealloc];
}

- (id)drawer
{
	return( mDrawer );
}

- (QTAMovieView*)getView
{
	return movieView;
}

- (QTMovie*)getMovie
{
	return( movie );
}

- (void)setMovie:(QTMovie *)m
{
	if(m != movie)
	{ NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
		if(movie){
			[center removeObserver:self name:QTMovieDidEndNotification object:movie];
		}
		[movie release];
		if( isProgrammatic ){
			[movie autorelease];
		}
		if( m ){
			movie = [m retain];
			if(movie){
				[center addObserver:self selector:@selector(movieEnded:) name:QTMovieDidEndNotification object:movie];
				[self installMovieCallBack];
			}
		}
		else{
			movie = nil;
		}
		[movieView setMovie:movie];
		[mTimeDisplay setMovie:movie];
		[mRateDisplay setMovie:movie];
#ifdef SHADOW
		if(movieShadow)
			[center removeObserver:self name:QTMovieDidEndNotification object:movieShadow];
		[movieShadow release];
		movieShadow = [m retain];
		if(movieShadow){
			[center addObserver:self selector:@selector(movieEnded:) name:QTMovieDidEndNotification object:movieShadow];
//			[self installMovieCallBack];
		}
		[movieShadowView setMovie:movieShadow];
#endif
		[self setOneToOne:self];
		resizesVertically = ([self moviePreferredSize].height >= 2);
		playAllFrames= ( [[movie attributeForKey:QTMoviePlaysAllFramesAttribute] boolValue] )? NSOnState : NSOffState;
		Loop= ( [[movie attributeForKey:QTMovieLoopsAttribute] boolValue] )? NSOnState : NSOffState;

		if( m!= nil ){
			MyDocList *new= (MyDocList*) calloc( 1, sizeof(MyDocList) );
			if( new ){
				new->docwin= self;
				new->cdr= DocList;
				new->id= MyDocs;
				new->playing= 0;
				if( DocList ){
					DocList->car= new;
				}
				DocList= new;
				MyDocs+= 1;
			}
		}
		else{
		  MyDocList *list= DocList, *next;
			while( list ){
				next= list->cdr;
				if( list->docwin== self ){
					if( list== DocList ){
						DocList->car= NULL;
						DocList= DocList->cdr;
					}
					else{
						if( list->cdr ){
							list->cdr->car= list->car;
						}
						if( list->car ){
							list->car->cdr = list->cdr;
						}
					}
					list->docwin= NULL;
					list->car= list->cdr= NULL;
					free(list);
					MyDocs-= 1;
				}
				list= next;
			}
		}
	}
}

static NSMenuItem *NormalMI=NULL, *HalfMI=NULL, *DoubleMI= NULL, *MaxMI=NULL,
	*PlayAllFramesMI= NULL, *FullScreenMI=NULL, *SpanningMI=NULL, *PlayAllFramesAllMI= NULL,
	*LoopMI= NULL, *LoopAllMI= NULL;
static int playAllFramesAll= 0, LoopAll= 0;

- (void)updateMenus
{
	if( HalfMI ){
		[HalfMI setState:halfSize];
	}
	if( NormalMI ){
		[NormalMI setState:normalSize];
	}
	if( DoubleMI ){
		[DoubleMI setState:doubleSize];
	}
	if( MaxMI ){
		[MaxMI setState:maxSize];
	}
	if( FullScreenMI ){
		[FullScreenMI setState:((inFullscreen)?NSOnState : NSOffState)];
	}
	if( SpanningMI ){
		[SpanningMI setState:((inFullscreen)?NSOnState : NSOffState)];
	}
	playAllFrames= ( [[movie attributeForKey:QTMoviePlaysAllFramesAttribute] boolValue] )? NSOnState : NSOffState;
	Loop= ( [[movie attributeForKey:QTMovieLoopsAttribute] boolValue] )? NSOnState : NSOffState;
	if( PlayAllFramesMI ){
		[PlayAllFramesMI setState:playAllFrames];
	}
	if( PlayAllFramesAllMI ){
		[PlayAllFramesAllMI setState:playAllFramesAll];
	}
	if( LoopMI ){
		[LoopMI setState:Loop];
	}
	if( LoopAllMI ){
		[LoopAllMI setState:LoopAll];
	}
	[self setCurrentSizeDisplay];
	if( (InfoDrawer= [mDrawer state])== NSDrawerOpeningState ){
		InfoDrawer= NSDrawerOpenState;
	}
	else if( InfoDrawer== NSDrawerClosingState ){
		InfoDrawer= NSDrawerClosedState;
	}
}

- (void)setOneToOne:sender
{
	NSSize size = [self moviePreferredSize];

	if( inFullscreen ){
		[self setMovieSize:size];
	}
	else{
		NSSize winSize = [self windowSizeForMovieSize:size];
		NSWindow *window = [movieView window];
		NSRect winRect = [window frame];
		float dy = winSize.height - winRect.size.height;
		winRect.origin.y -= dy;
		winRect.size = winSize;
		[window setFrame:winRect display:YES animate:NO];
		[self setMovieSize:size];
	}

	if( sender!= self ){
		NormalMI= sender;
	}
	normalSize= NSOnState;
	halfSize= doubleSize= maxSize= NSOffState;
	[self updateMenus];
}

- (void)setHalfSize:sender
{
	NSSize size = [self moviePreferredSize];
	size.width /= 2.0;
	size.height /= 2.0;

	if( inFullscreen ){
		[self setMovieSize:size];
	}
	else{
		NSSize winSize = [self windowSizeForMovieSize:size];
		NSWindow *window = [movieView window];
		NSRect winRect = [window frame];
		float dy = winSize.height - winRect.size.height;
		winRect.origin.y -= dy;
		winRect.size = winSize;
		[self setMovieSize:size];
		[window setFrame:winRect display:YES animate:NO];
	}

	if( sender!= self ){
		HalfMI= sender;
	}
	halfSize= NSOnState;
	normalSize= doubleSize= maxSize= NSOffState;
	[self updateMenus];
}

- (void)setDoubleSize:sender
{
	NSSize size = [self moviePreferredSize];
	size.width *= 2.0;
	size.height *= 2.0;

	if( inFullscreen ){
		[self setMovieSize:size];
	}
	else{
		NSSize winSize = [self windowSizeForMovieSize:size];
		NSWindow *window = [movieView window];
		NSRect winRect = [window frame];
		float dy = winSize.height - winRect.size.height;
		winRect.origin.y -= dy;
		winRect.size = winSize;
		[self setMovieSize:size];
		[window setFrame:winRect display:YES animate:NO];
	}

	if( sender!= self ){
		DoubleMI= sender;
	}
	doubleSize= NSOnState;
	normalSize= halfSize= maxSize= NSOffState;
	[self updateMenus];
}

- (void)setFullscreenSize:sender
{
	NSWindow *window = [movieView window];
	NSRect newFrame = [[window screen] visibleFrame];
	NSSize movieSize = [self movieSizeForWindowSize:newFrame.size];
	NSSize idealSize = [self sizeWithMovieAspectFromSize:movieSize];
	NSSize idealWindowSize = [self windowSizeForMovieSize:idealSize];

	float dx = newFrame.size.width - idealWindowSize.width;
	float dy = newFrame.size.height - idealWindowSize.height;

	if( inFullscreen ){
		[self setMovieSize:idealSize];
	}
	else{
		newFrame.origin.x += dx / 2.0;
		newFrame.origin.y += dy / 2.0;
		newFrame.size = idealWindowSize;

		[self setMovieSize:idealSize];
		[window setFrame:newFrame display:YES animate:NO];
	}

	if( sender!= self ){
		MaxMI= sender;
	}
	maxSize= NSOnState;
	normalSize= halfSize= doubleSize= NSOffState;
	[self updateMenus];
}

- (void)setHalvedSize:sender
{
	NSSize size = [self movieCurrentSize];
	size.width /= 2.0;
	size.height /= 2.0;

	if( inFullscreen ){
		[self setMovieSize:size];
	}
	else{
		NSSize winSize = [self windowSizeForMovieSize:size];
		NSWindow *window = [movieView window];
		NSRect winRect = [window frame];
		float dy = winSize.height - winRect.size.height;
		winRect.origin.y -= dy;
		winRect.size = winSize;
		[self setMovieSize:size];
		[window setFrame:winRect display:YES animate:NO];
	}

	if( normalSize== NSOnState ){
		halfSize= NSOnState;
	}
	else{
		halfSize= NSOffState;
	}
	normalSize= doubleSize= maxSize= NSOffState;
	[self updateMenus];
}

- (void)setHalvedSizeAll:sender
{ MyDocList *list= DocList;
	while( list ){
		[list->docwin setHalvedSize:sender];
		list= list->cdr;
	}
}

- (void)setDoubledSize:sender
{
	NSSize size = [self movieCurrentSize];
	size.width *= 2.0;
	size.height *= 2.0;

	if( inFullscreen ){
		[self setMovieSize:size];
	}
	else{
		NSSize winSize = [self windowSizeForMovieSize:size];
		NSWindow *window = [movieView window];
		NSRect winRect = [window frame];
		float dy = winSize.height - winRect.size.height;
		winRect.origin.y -= dy;
		winRect.size = winSize;
		[self setMovieSize:size];
		[window setFrame:winRect display:YES animate:NO];
	}

	if( halfSize== NSOnState ){
		normalSize= NSOnState;
		doubleSize= NSOffState;
	}
	else if( normalSize== NSOnState ){
		doubleSize= NSOnState;
		normalSize= NSOffState;
	}
	else{
		doubleSize= NSOffState;
		normalSize= NSOffState;
	}
	halfSize= maxSize= NSOffState;
	[self updateMenus];
}

- (void)setDoubledSizeAll:sender
{ MyDocList *list= DocList;
	while( list ){
		[list->docwin setDoubledSize:sender];
		list= list->cdr;
	}
}

- (void)setFullscreen:sender
{
	if( sender!= self ){
		FullScreenMI= sender;
	}
	if( inFullscreen ){
		[self endFullscreen];
	}
	else{
		[self beginFullscreen:FSRegular];
	}
	[self updateMenus];
}

- (void)setSpanning:sender
{
	if( sender!= self ){
		SpanningMI= sender;
	}
	if( inFullscreen ){
		[self endFullscreen];
	}
	else{
		[self beginFullscreen:FSSpanning];
	}
	[self updateMenus];
}

- (void)goPosterFrame:sender
{
	if( inFullscreen ){
		[fullscreenMovieView gotoPosterFrame:self];
	}
	else{
		[movieView gotoPosterFrame:self];
	}
}

- (void)goBeginning:sender
{
	if( inFullscreen ){
		[fullscreenMovieView gotoBeginning:self];
	}
	else{
		[movieView gotoBeginning:self];
	}
}

- (void)setPBAll:sender
{ QTMovie *m= (inFullscreen)? [fullscreenMovieView movie] : [movieView movie];
	playAllFrames= ( [[m attributeForKey:QTMoviePlaysAllFramesAttribute] boolValue] )? NSOnState : NSOffState;
	if( playAllFrames!= NSOffState ){
		[m setAttribute:[NSNumber numberWithBool:NO] forKey:QTMoviePlaysAllFramesAttribute];
		playAllFrames= NSOffState;
		playAllFramesAll= (playAllFramesAll!=NSOffState && MyDocs>1)? NSMixedState : NSOffState;
	}
	else{
		[m setAttribute:[NSNumber numberWithBool:YES] forKey:QTMoviePlaysAllFramesAttribute];
		playAllFrames= NSOnState;
	}
	if( sender!= self ){
		PlayAllFramesMI= sender;
	}
	[self updateMenus];
}

- (void)setAllPBAll:sender
{ MyDocList *list= DocList;
	while( list ){
		QTMovie *m= (list->docwin->inFullscreen)? [list->docwin->fullscreenMovieView movie] : [list->docwin->movieView movie];
		if( playAllFramesAll!= NSOffState ){
			[m setAttribute:[NSNumber numberWithBool:NO] forKey:QTMoviePlaysAllFramesAttribute];
			list->docwin->playAllFrames= NSOffState;
//			playAllFramesAll= (playAllFramesAll!=NSOffState && MyDocs>1)? NSMixedState : NSOffState;
		}
		else{
			[m setAttribute:[NSNumber numberWithBool:YES] forKey:QTMoviePlaysAllFramesAttribute];
			list->docwin->playAllFrames= NSOnState;
//			playAllFrames= NSOnState;
		}
		list= list->cdr;
	}
	if( playAllFramesAll!= NSOffState ){
		playAllFramesAll= NSOffState;
	}
	else{
		playAllFramesAll= NSOnState;
	}
	if( sender!= self ){
		PlayAllFramesAllMI= sender;
	}
	[self updateMenus];
}

- (void)setLoop:sender
{ QTMovie *m= (inFullscreen)? [fullscreenMovieView movie] : [movieView movie];
	Loop= ( [[m attributeForKey:QTMovieLoopsAttribute] boolValue] )? NSOnState : NSOffState;
	if( Loop!= NSOffState ){
		[m setAttribute:[NSNumber numberWithBool:NO] forKey:QTMovieLoopsAttribute];
		Loop= NSOffState;
		LoopAll= (LoopAll!=NSOffState && MyDocs>1)? NSMixedState : NSOffState;
	}
	else{
		[m setAttribute:[NSNumber numberWithBool:YES] forKey:QTMovieLoopsAttribute];
		Loop= NSOnState;
	}
	if( sender!= self ){
		LoopMI= sender;
	}
	[self updateMenus];
}

- (void)setLoopAll:sender
{ MyDocList *list= DocList;
	while( list ){
		QTMovie *m= (list->docwin->inFullscreen)? [list->docwin->fullscreenMovieView movie] : [list->docwin->movieView movie];
		if( LoopAll!= NSOffState ){
			[m setAttribute:[NSNumber numberWithBool:NO] forKey:QTMovieLoopsAttribute];
			list->docwin->Loop= NSOffState;
		}
		else{
			[m setAttribute:[NSNumber numberWithBool:YES] forKey:QTMovieLoopsAttribute];
			list->docwin->Loop= NSOnState;
		}
		list= list->cdr;
	}
	if( LoopAll!= NSOffState ){
		LoopAll= NSOffState;
	}
	else{
		LoopAll= NSOnState;
	}
	if( sender!= self ){
		LoopAllMI= sender;
	}
	[self updateMenus];
}

- (void)goPosterFrameAll:sender
{ MyDocList *list= DocList;
	while( list ){
		if( inFullscreen ){
			[list->docwin->fullscreenMovieView gotoPosterFrame:self];
		}
		else{
			[list->docwin->movieView gotoPosterFrame:self];
		}
		list= list->cdr;
	}
}

- (void)goBeginningAll:sender
{ MyDocList *list= DocList;
	while( list ){
		if( inFullscreen ){
			[list->docwin->fullscreenMovieView gotoBeginning:self];
		}
		else{
			[list->docwin->movieView gotoBeginning:self];
		}
		list= list->cdr;
	}
}

- (void)playAll:sender
{ MyDocList *list= DocList;
  int state= 0;
	while( list ){
		if( list->docwin ){
			if( list->playing ){
				list->playing= 0;
				[ list->docwin->movieView pause:list->docwin ];
				state+= NSOffState;
			}
			else{
				list->playing= 1;
				[ list->docwin->movieView play:list->docwin ];
				state+= NSOnState;
			}
		}
		list= list->cdr;
	}
	if( MyDocs ){
		state/= MyDocs;
	}
	if( sender!= self ){
		if( state== NSOnState || state== NSOffState ){
			[sender setState:state];
		}
		else{
			[sender setState:NSMixedState];
		}
	}
}

- (void)playAllFullScreen:sender
{ MyDocList *list= DocList;
  int n= 0;
	while( list ){
		if( list->docwin ){
			if( list->playing ){
				list->playing= 0;
				[ list->docwin endFullscreen ];
			}
			else{
				list->playing= 1;
				[ list->docwin makeFullscreenView:FSMosaic ];
			}
		}
		list= list->cdr;
	}
	list= DocList;
	while( list ){
		if( list->docwin ){
			if( list->playing ){
				[ list->docwin->fullscreenMovieView play:list->docwin];
				n+= 1;
			}
		}
		list= list->cdr;
	}

	if( n ){
		[self disableSleep];
	}
	if( sender!= self ){
		if( n== MyDocs ){
			[sender setState:NSOnState];
		}
		else{
			[sender setState:((n)?NSMixedState:NSOffState)];
		}
	}
}

- (void)stepForwardAll:sender
{ MyDocList *list= DocList;
	while( list ){
		if( inFullscreen ){
			[list->docwin->fullscreenMovieView stepForward:self];
		}
		else{
			[list->docwin->movieView stepForward:self];
		}
		list= list->cdr;
	}
}

- (void)stepBackwardAll:sender
{ MyDocList *list= DocList;
	while( list ){
		if( inFullscreen ){
			[list->docwin->fullscreenMovieView stepBackward:self];
		}
		else{
			[list->docwin->movieView stepBackward:self];
		}
		list= list->cdr;
	}
}

- (void)toggleInfoDrawer:sender
{
	[mDrawer toggle:sender];
	if( (InfoDrawer= [mDrawer state])== NSDrawerOpeningState ){
		InfoDrawer= NSDrawerOpenState;
		[self UpdateDrawer];
	}
	else if( InfoDrawer== NSDrawerClosingState ){
		InfoDrawer= NSDrawerClosedState;
	}
}

- (void)setTimeDisplay
{
	if( movie && InfoDrawer ){
	  QTTime currentPlayTime = [[movie attributeForKey:QTMovieCurrentTimeAttribute] QTTimeValue];
		[mTimeDisplay setStringValue:QTStringFromTime(currentPlayTime) /*+@"@"+[NSString stringWithFormat:@"%d",[movie rate]] */ ];
//		NSLog( @"Playing=%d@%g, TC=%@", Playing, [movie rate], QTStringFromTime(currentPlayTime) );
//		{ NSTimeInterval timeInterval;
//			if( QTGetTimeInterval(currentPlayTime, &timeInterval) ){
//				NSLog( @"Playing=%d@%g, TC=%@ = %g", Playing, [movie rate], QTStringFromTime(currentPlayTime), timeInterval );
//			}
//			else{
//				NSLog( @"Playing=%d@%g, TC=%@ can't determine timeinterval", Playing, [movie rate], QTStringFromTime(currentPlayTime) );
//			}
//		}
	}
}

- (void)gotoTime:sender
{
	if( movie && InfoDrawer!= NSDrawerClosedState ){
	  NSString *stime = [mTimeDisplay stringValue];
	  NSString *srate = [mRateDisplay stringValue];
		if( stime ){
		  QTTime ntime= QTTimeFromString(stime);
			if( (ntime.flags & kQTTimeIsIndefinite) != kQTTimeIsIndefinite ){
				[movie setCurrentTime:ntime];
				[self setTimeDisplay];
			}
			else{
				NSLog( @"Can't read QT time from \"%@\"", stime );
			}
		}
		else{
			NSLog( @"Can't read string from %@", [mTimeDisplay objectValue] );
		}
		if( srate ){
		  float rate = [srate floatValue];
		  BOOL p = Playing;
			if( rate > 0 && rate < HUGE_VAL ){
				if( p ){
					[movie setRate:rate];
				}
				[movie setAttribute:[NSNumber numberWithFloat:rate] forKey:QTMoviePreferredRateAttribute];
				[self setRateDisplay];
			}
			else{
				NSLog( @"Can't read QT rate from \"%@\" (-> %g)", srate, (double) rate );
			}
		}
		else{
			NSLog( @"Can't read string from %@", [mRateDisplay objectValue] );
		}
	}
}

- (void)setDurationDisplay
{
	if( movie && InfoDrawer ){
		if( [movie attributeForKey:QTMovieHasDurationAttribute] ){
		  NSString *durStr = QTStringFromTime([[movie attributeForKey:QTMovieDurationAttribute] QTTimeValue]);
			if( durStr ){
				[mDuration setStringValue:durStr];
			}
		}
	}
}

- (void)setRateDisplay
{
	if( movie && InfoDrawer ){
	 NSMutableString *rateString = [NSMutableString string];
		if( Playing ){
			[rateString appendFormat:@"%g x", (double) [movie rate] ];
		}
		else{
			[rateString appendFormat:@"%@ x", [movie attributeForKey:QTMoviePreferredRateAttribute] ];
		}
		[mRateDisplay setStringValue:rateString];
	}
}

- (void)setNormalSizeDisplay
{
	if( movie && InfoDrawer ){
	  NSMutableString *sizeString = [NSMutableString string];
	  NSSize movSize = NSMakeSize(0,0);
	  movSize = [[movie attributeForKey:QTMovieNaturalSizeAttribute] sizeValue];

		[sizeString appendFormat:@"%.0f", movSize.width];
		[sizeString appendString:@" x "];
		[sizeString appendFormat:@"%.0f", movSize.height];

		[mNormalSize setStringValue:sizeString];
	}
}

- (void)setCurrentSizeDisplay
{
	if( movie && InfoDrawer ){
	  NSSize movCurrentSize = NSMakeSize(0,0);
	  movCurrentSize = [[movie attributeForKey:QTMovieCurrentSizeAttribute] sizeValue];
	  NSMutableString *sizeString = [NSMutableString string];

		if( movie && [movieView isControllerVisible] ){
			movCurrentSize.height -= [movieView controllerBarHeight];
		}

		[sizeString appendFormat:@"%.0f", movCurrentSize.width];
		[sizeString appendString:@" x "];
		[sizeString appendFormat:@"%.0f", movCurrentSize.height];

		[mCurrentSize setStringValue:sizeString];
	}
}

- (void)setSource:(NSString *)name
{ NSArray *pathComponents = [[NSFileManager defaultManager] componentsToDisplayForPath:name];
  NSEnumerator *pathEnumerator = [pathComponents objectEnumerator];
  NSString *component = [pathEnumerator nextObject];
  NSMutableString *displayablePath = [NSMutableString string];

	while( component != nil ){
		if( [component length] > 0 ){
			[displayablePath appendString:component];

			component = [pathEnumerator nextObject];
			if( component != nil ){
				[displayablePath appendString:@":"];
			}
		}
		else{
			component = [pathEnumerator nextObject];
		}
	}

	[mSourceName setStringValue:displayablePath];
}

- (void)UpdateDrawer
{
	[self setTimeDisplay];
	[self setDurationDisplay];
	[self setRateDisplay];
	[self setNormalSizeDisplay];
	[self setCurrentSizeDisplay];
	[self setSource:[self fileName]];
}

- (void)doExportSettings:sender
{
	int componentIndex = [exportTypePopup indexOfSelectedItem];
	[exportManager showSettingsAtIndex:componentIndex];
}

- (void)exportPopupChanged:sender
{
	NSArray *components = [[MAMovieExport sharedInstance] componentList];
	NSString *info = [[components objectAtIndex:[exportTypePopup indexOfSelectedItem]] objectForKey:kMAMovieExportComponentInfo];
	if(!info) info = NSLocalizedString(@"No info", @"");
	[exportInfoField setStringValue:info];
}

static unsigned int fullScreenViews= 0;

- (void)makeFullscreenView:(FSStyle)style
{
	if(inFullscreen) return;

	NSWindow *window = [movieView window];
	NSScreen *screen = [window screen];
	NSRect screensRect;
	NSEnumerator *enumerator;
	id scr;
	float minHeight= -1, minX= -1, theY= 0;

	if( style == FSSpanning ){
		memset( &screensRect, 0, sizeof(screensRect) );
		if( [NSScreen screens] ){
			enumerator = [[NSScreen screens] objectEnumerator];
			while( scr = [enumerator nextObject] ){
			  NSRect r = [scr frame];
				screensRect.size.width += r.size.width;
//				NSLog( @"Screen %@ %gx%g+%g+%g", scr, r.size.width, r.size.height, r.origin.x, r.origin.y );
				if( minHeight< 0 || r.size.height< minHeight ){
					minHeight = r.size.height;
				}
				if( minX< 0 || r.origin.x< minX ){
					minX = r.origin.x;
					theY = r.origin.y;
				}
			}
			screensRect.size.height = minHeight;
			screensRect.origin.x = minX;
			screensRect.origin.y = theY;
			NSLog( @"Screen-spanning rect: %gx%g+%g+%g", screensRect.size.width, minHeight, screensRect.origin.x, screensRect.origin.y );
		}
	}

	[window orderOut:self];
	[movieView setMovie:nil];

	if( style == FSSpanning ){
		[fullscreenWindow setFrame:screensRect display:YES];
	}
	else{
		[fullscreenWindow setFrame:[screen frame] display:YES];
	}

	[fullscreenMovieView setMovie:movie];
	[fullscreenWindow makeKeyAndOrderFront:self];

	if([screen isEqual:[NSScreen mainScreen]])
		SetSystemUIMode(kUIModeAllHidden, 0);

	inFullscreen = YES;
	fullScreenViews += 1;
}

- (void)beginFullscreen:(FSStyle)style
{
	if( !inFullscreen ){
		[self makeFullscreenView:style];
	}

	NSLog( @"Starting fullscreen playback self=%p%@ super=%p fMV=%p%@",
		  self, self, super, fullscreenMovieView, fullscreenMovieView
	);
	[fullscreenMovieView pplay:self];

	[self disableSleep];
}

- (void)endFullscreen
{
	if(!inFullscreen) return;

	NSLog( @"Ending fullscreen playback self=%p%@ super=%p fMV=%p%@ views=%u",
		  self, self, super, fullscreenMovieView, fullscreenMovieView, fullScreenViews
	);

	if( fullScreenViews> 0 ){
		fullScreenViews -= 1;
	}
	if( fullScreenViews== 0 ){
		SetSystemUIMode(kUIModeNormal, 0);
	}

	[fullscreenMovieView pause:self];
	[fullscreenWindow orderOut:self];
	[fullscreenMovieView setMovie:nil];

	[movieView setMovie:movie];
	[movieView setControllerVisible:YES];
	[[movieView window] makeKeyAndOrderFront:self];

	[self enableSleep];

	inFullscreen = NO;
}

- (void)updateSystemActivity:(NSTimer *)timer
{
	UpdateSystemActivity(OverallAct);
}

- (void)disableSleep
{
	if(!dontSleepTimer)
		dontSleepTimer = [[NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(updateSystemActivity:) userInfo:nil repeats:YES] retain];
}

- (void)enableSleep
{
	[dontSleepTimer invalidate];
	[dontSleepTimer release];
	dontSleepTimer = nil;
}

// document stuff

-(void)awakeFromNib
{
	// initialise movie drawer items
	InfoDrawer= [mDrawer state];
	[self UpdateDrawer];
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
	[movieView setMovie:movie];
	[self setOneToOne:self];
	InfoDrawer= [mDrawer state];

	[[movieView window] setShowsResizeIndicator:NO];
	[movieView setShowsResizeIndicator:YES];
}

- (NSData *)dataRepresentationOfType:(NSString *)aType
{
    // Insert code here to write your document from the given data.  You can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.

    // For applications targeted for Tiger or later systems, you should use the new Tiger API -dataOfType:error:.  In this case you can also choose to override -writeToURL:ofType:error:, -fileWrapperOfType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.

    return nil;
}

#include <unistd.h>

static MyDocument *m2 = NULL;

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	QTMovie *m = [QTMovie movieWithURL:absoluteURL error:outError];
	if(!m){
	  static char active=0;
	  NSString *fileName = [absoluteURL path];
	  BOOL res = NO;
		if( *outError ){
			NSLog( @"Error opening \"%@\": reason=\"%@\", description=\"%@\", suggestions=\"%@\"\n",
				  fileName,
				  [*outError localizedFailureReason],
				  [*outError localizedDescription],
				  [*outError localizedRecoverySuggestion]
			);
		}
		/* let's try if this is a temporary Flash video file, usually stored somewhere in
		 \ /var/tmp/folders.<UID>/TemporaryItems
		 \ and with a name like FlashTmp0 . Those are flv files, but QT is stupid enough to recognise them
		 \ only from the file extension. One thus needs to add the extension, and then things work (provided the proper
		 \ codec is installed if so required). Rather than obliging the user to do so, we do it here, renaming the file
		 \ to a hopefully unique temporary name, opening it, and then renaming it back immediately. OS X is smart enough
		 \ to allow this - the window that opens even shows the correct (original) filename!
		 */
		if( !active ){
		  NSRange flashtmp = [fileName rangeOfString:@"FlashTmp"];
		  NSString *flv;
			if( flashtmp.length ){
			  const char *from, *to;
				active += 1;
				flv = [fileName stringByAppendingString:
						[[NSString stringWithCString:mktemp(".QTAmtr")] stringByAppendingString:@".flv"] ];
				from = [fileName UTF8String], to = [flv UTF8String];
				if( rename( from, to ) ){
					NSLog( @"Error renaming \"%s\" to \"%s\": %s\n", from, to, strerror(errno) );
				}
				else{
					NSLog( @"Temporarily renamed \"%@\" to \"%@\"\n", fileName, flv );
					res = [self readFromURL:[NSURL fileURLWithPath:flv] ofType:typeName error:outError];
					rename( to, from );
				}
				active -= 1;
			}
		}
		return res;
	}
	NSLog( @"Opened \"%@\" (process %u:%u)\n", [absoluteURL path], getpid(), pthread_self() );
	{ MatrixRecord M;
	  Fixed tw, th;
	  Rect src, dst;
	  Track theTrack = GetMovieIndTrack( [m quickTimeMovie], 1 );
	  PixMapHandle trackMatte;
	  RgnHandle clipRgn;
		GetTrackMatrix( theTrack, &M );
		GetTrackDimensions( theTrack, &tw, &th );
		trackMatte = GetTrackMatte( theTrack );
		clipRgn = GetTrackClipRgn( theTrack );
		NSLog( @"Matrix type %d\n[[%d\t%d\t%d]\n"
			  " [%d\t%d\t%d]\n"
			  " [%d\t%d\t%d]] %dx%d\n",
			  GetMatrixType(&M),
			  FixRound(M.matrix[0][0]), FixRound(M.matrix[0][1]), FixRound(M.matrix[0][2]),
			  FixRound(M.matrix[1][0]), FixRound(M.matrix[1][1]), FixRound(M.matrix[1][2]),
			  FixRound(M.matrix[2][0]), FixRound(M.matrix[2][1]), FixRound(M.matrix[2][2]),
			  FixRound(tw), FixRound(th)
		);
#if 0
		dst.right = src.left = 0;
		dst.top = src.left = src.top = 0;
		dst.left = src.right = FixRound(tw);
		dst.bottom = src.bottom = FixRound(th);
		MapMatrix( &M, &src, &dst );
#endif
	}
	[self setMovie:m];
	if( isProgrammatic ){
		[[movieView window] setDelegate:self];
	}
#if 1
	{ static char active = 0;
		if( !active ){
			active = 1;
			m2 = [MyDocument alloc];
			if( m2 ){
				m2->isProgrammatic = TRUE;
				[NSBundle loadNibNamed:@"MyDocument" owner:m2];
				absoluteURL = [NSURL fileURLWithPath:@"/Volumes/Debian/Users/bertin/work/src/MacOSX/QTilities/QTils/Sample.mov"];
				if( [m2 initWithContentsOfURL:absoluteURL ofType:typeName error:outError] != nil ){
					[m2 makeWindowControllers];
//					[m2 retain];
					[m2 showWindows];
				}
			}
			active = 0;
		}
	}
#endif
	return YES;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName
{
	NSError *error = nil;
	return [self readFromURL:absoluteURL ofType:typeName error:&error];
}


- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)docType
{
	NSURL *url = [NSURL fileURLWithPath:fileName];
	NSError *error = nil;
	return [self readFromURL:url ofType:docType error:&error];
}

// RJVB 20091214: override the default saveDocumentAs() method:
- (IBAction)saveDocumentAs:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	[panel setPrompt:NSLocalizedString(@"Save (reference)", @"")];
	[panel setTitle:NSLocalizedString(@"Save (reference)", @"")];
	[panel setNameFieldLabel:NSLocalizedString(@"Save (reference) As:", @"")];
	// we'd really like to be sure we save files of the right type - QT is a little braindead about that!
	[panel setRequiredFileType:@"mov"];
	[panel setCanSelectHiddenExtension:YES];

	[panel beginSheetForDirectory:nil file:nil
				modalForWindow:[movieView window] modalDelegate:self
				didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:NULL ];
}

- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(int)code contextInfo:(void *)ctx
{
	if(code == NSOKButton)
	{
		// save the movie with the proper filename, and flattening it
		[movie writeToFile:[panel filename]
		    withAttributes:nil
		];
	}
}

- (IBAction)saveDocument:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	[panel setPrompt:NSLocalizedString(@"Save (contained)", @"")];
	[panel setTitle:NSLocalizedString(@"Save (contained)", @"")];
	[panel setNameFieldLabel:NSLocalizedString(@"Save (contained) As:", @"")];
	// we'd really like to be sure we save files of the right type - QT is a little braindead about that!
	[panel setRequiredFileType:@"mov"];
	[panel setCanSelectHiddenExtension:YES];

	[panel beginSheetForDirectory:nil file:nil
				modalForWindow:[movieView window] modalDelegate:self
				didEndSelector:@selector(savePanelDidEndFlat:returnCode:contextInfo:) contextInfo:NULL ];
}

- (void)savePanelDidEndFlat:(NSSavePanel *)panel returnCode:(int)code contextInfo:(void *)ctx
{
	if(code == NSOKButton)
	{
		// save the movie with the proper filename, and flattening it
		[movie writeToFile:[panel filename]
		    withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], QTMovieFlatten, nil]
		];
	}
}

- (IBAction)saveDocumentTo:(id)sender
{
	if(!exportManager)
		exportManager = [[ExportManager alloc] initWithQTMovie:movie];

	// first, prepare the accessory view
	NSArray *components = [[MAMovieExport sharedInstance] componentList];
	int count = [components count];
	int i;

	[exportTypePopup removeAllItems];
	for(i = 0; i < count; i++)
	{
		NSString *name = [[components objectAtIndex:i] objectForKey:kMAMovieExportComponentName];
		if(!name) name = [[components objectAtIndex:i] objectForKey:kMAMovieExportComponentFileExtension];
		if(!name) name = @"(null)";
		[[exportTypePopup menu] addItemWithTitle:name action:NULL keyEquivalent:@""];
	}

	int index = [exportManager defaultIndex];
	[exportTypePopup selectItemAtIndex:index];
	[self exportPopupChanged:self];

	NSSavePanel *panel = [NSSavePanel savePanel];
	[panel setAccessoryView:exportAccessoryView];
	[panel setPrompt:NSLocalizedString(@"Export", @"")];
	[panel setTitle:NSLocalizedString(@"Export", @"")];
	[panel setNameFieldLabel:NSLocalizedString(@"Export To:", @"")];

	[panel beginSheetForDirectory:nil file:nil modalForWindow:[movieView window] modalDelegate:self didEndSelector:@selector(exportPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)exportPanelDidEnd:(NSSavePanel *)panel returnCode:(int)code contextInfo:(void *)ctx
{
	[exportManager setDefaultIndex:[exportTypePopup indexOfSelectedItem]];

	if(code == NSOKButton)
	{
		int componentIndex = [exportTypePopup indexOfSelectedItem];
		[exportManager exportToFile:[panel filename] named:[self displayName] atIndex:componentIndex];
	}
}

- (void)windowDidResize:(NSNotification *)dummy
{
	[self setCurrentSizeDisplay];
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize
{
	if(!([[sender currentEvent] modifierFlags] & NSShiftKeyMask) || !resizesVertically)
	{
		NSSize movieSize = [self movieSizeForWindowSize:frameSize];
		NSSize idealSize = [self sizeWithMovieAspectFromSize:movieSize];
		NSSize idealWindowSize = [self windowSizeForMovieSize:idealSize];
		return idealWindowSize;
	}
	else
		return frameSize;
}

- (NSRect)windowWillUseStandardFrame:(NSWindow *)sender defaultFrame:(NSRect)newFrame
{
	if(!([[sender currentEvent] modifierFlags] & NSShiftKeyMask) || !resizesVertically)
	{
		NSSize movieSize = [self movieSizeForWindowSize:newFrame.size];
		NSSize idealSize = [self sizeWithMovieAspectFromSize:movieSize];
		NSSize idealWindowSize = [self windowSizeForMovieSize:idealSize];

		float dx = newFrame.size.width - idealWindowSize.width;
		float dy = newFrame.size.height - idealWindowSize.height;

		newFrame.origin.x += dx / 2.0;
		newFrame.origin.y += dy / 2.0;
		newFrame.size = idealWindowSize;

		return newFrame;
	}
	else
		return newFrame;
}

- (void)windowDidUpdate:(NSNotification *)dummy
{
	[self setCurrentSizeDisplay];
}

- (void)windowDidExpose:(NSNotification *)dummy
{
	[self setCurrentSizeDisplay];
}

- (void)performClose:sender
{
	if(inFullscreen)
		[self endFullscreen];
}

- (void)movieEnded:(NSNotification *)notification
{
	[self performClose:self];
}

//- (BOOL)validateMenuItem:(id <NSMenuItem>)item
- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	SEL sel = [item action];
	return /* sel != @selector(saveDocument:)
		&& sel != @selector(saveDocumentAs:)
		&& */ sel != @selector(revertDocumentToSaved:)
		&& sel != @selector(runPageLayout:)
		&& sel != @selector(printDocument:);
}

- (void)dumpTypes
{
	/*NSMutableString *str = [NSMutableString string];

	NSString *format = @"\t\t<dict>\n"
		"\t\t\t<key>CFBundleTypeExtensions</key>\n"
		"\t\t\t<array>\n"
		"\t\t\t\t<string>%@</string>\n"
		"\t\t\t</array>\n"
		"\t\t\t<key>CFBundleTypeIconFile</key>\n"
		"\t\t\t<string></string>\n"
		"\t\t\t<key>CFBundleTypeName</key>\n"
		"\t\t\t<string>AllFiles</string>\n"
		"\t\t\t<key>CFBundleTypeOSTypes</key>\n"
		"\t\t\t<array>\n"
		"\t\t\t\t<string>%@</string>\n"
		"\t\t\t</array>\n"
		"\t\t\t<key>CFBundleTypeRole</key>\n"
		"\t\t\t<string>Viewer</string>\n"
		"\t\t\t<key>NSDocumentClass</key>\n"
		"\t\t\t<string>MyDocument</string>\n"
		"\t\t</dict>\n";*/

	NSMutableString *typeExtensionsString = [NSMutableString string];
	NSMutableString *osTypesString = [NSMutableString string];

	NSEnumerator *enumerator = [[QTMovie movieFileTypes:QTIncludeStillImageTypes] objectEnumerator];
	NSString *type;
	while((type = [enumerator nextObject]))
	{
		NSMutableString *toAppend = typeExtensionsString;
		if([type length] == 6 && [type characterAtIndex:0] == '\'' && [type characterAtIndex:5] == '\'')
		{
			toAppend = osTypesString;
			type = [type substringWithRange:NSMakeRange(1, 4)];
		}
		[toAppend appendFormat:@"\t\t\t\t<string>%@</string>\n", type];
	}

	NSLog(@"Types:\n\n\nextensions:\n%@\n\n\nostypes:\n%@\n\n\n", typeExtensionsString, osTypesString);
}

- (void) removeMovieCallBack
{
	NSLog( @"removeMovieCallBack %@", movie );
	MCSetActionFilterWithRefCon( [movie quickTimeMovieController], nil, (long) self );
}

- (void) installMovieCallBack
{
	callbackResult= noErr;

	MovieController mc= [movie quickTimeMovieController];
	MCActionFilterWithRefConUPP upp= NewMCActionFilterWithRefConUPP(QTActionCallBack);

	if( mc && upp ){
		callbackResult= MCSetActionFilterWithRefCon( mc, upp, (long) self );
	}
	if( upp ){
		DisposeMCActionFilterWithRefConUPP(upp);
	}
}

- (BOOL) windowShouldClose:(id)sender
{
	if( isProgrammatic ){
		[self removeMovieCallBack];
		[self setMovie:nil];
		[self autorelease];
	}
	return YES;
}

- (void) windowWillClose:(NSNotification*)notification
{ NSWindow *nswin = [notification object];
	NSLog( @"[%@ %@%@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd), nswin );
}

@end

#ifdef DEBUG
#	include <stdio.h>
#endif

#define mcFeedBack(mydoc,actionStr)	{ \
	NSLog( @"%s: %@ %@ Stepped=%d Scanned=%d par=%p (process %u:%p)", actionStr, [mydoc getMovie], \
		  QTStringFromTime([[[mydoc getMovie] attributeForKey:QTMovieCurrentTimeAttribute] QTTimeValue]), \
		  mydoc->wasStepped, mydoc->wasScanned, params, \
		  getpid(), pthread_self() \
	); \
	fname = [ [[mydoc getMovie] attributeForKey:QTMovieFileNameAttribute] fileSystemRepresentation]; \
	timestr = [ QTStringFromTime([[[mydoc getMovie] attributeForKey:QTMovieCurrentTimeAttribute] QTTimeValue]) fileSystemRepresentation]; \
	fprintf( stderr, "%s: %s %s rate=%g Stepped=%d Scanned=%d par=%p", actionStr, fname, timestr, \
		  (double)[[mydoc getMovie] rate], mydoc->wasStepped, mydoc->wasScanned, params \
	); \
	if( action == mcActionKeyUp ){ \
		fprintf( stderr, " key=%c", (char) ((EventRecord*) params)->message & charCodeMask ); \
	} \
	fprintf( stderr, " (process %u:%p)\n", getpid(), pthread_self() ); \
}

#ifdef DEBUG
OSErr MCSetMovieTime( Movie theMovie, MovieController theMC, TimeValue t )
{ OSErr err;
	if( theMovie ){
	  TimeRecord trec;
		GetMovieTime( theMovie, &trec );
		err = GetMoviesError();
		if( err == noErr ){
		  TimeScale scale;
			// trec.value is a 'wide', a structure containing a lo and a high int32 variable.
			// set it by casting to an int64 because that's the underlying intention ...
			*( (SInt64*)&(trec.value) ) = (SInt64)( t );
			SetMovieTime( theMovie, &trec );
			err = GetMoviesError();
			UpdateMovie( theMovie );
			if( theMC ){
				MCMovieChanged( theMC, theMovie );
				MCIdle( theMC );
			}
		}
	}
	else{
		err = paramErr;
	}
	return err;
}
#endif //DEBUG

static Boolean nothing( DialogPtr dialog, EventRecord *event, DialogItemIndex *itemhit )
{
#ifdef DEBUG
	NSLog( @"MovieInfo callback dialog=%@, event=%@, index=%@", dialog, event, itemhit );
#endif
	return 0;
}

static pascal Boolean QTActionCallBack( MovieController mc, short action, void* params, long refCon )
{  MyDocument *mydoc= (MyDocument*) refCon;
#ifdef DEBUG
   const char *fname, *timestr;
   QTTime curTime = [[[mydoc getMovie] attributeForKey:QTMovieCurrentTimeAttribute] QTTimeValue];
#endif
	// step/scan handling: user needs to be able to catch a finished action, which is the next following
	// Play event!
	// a Step event is (usually?) followed by a Play and then a GotoTime event
#if DEBUG == 2
	if( ((mydoc->wasStepped > 0 || mydoc->wasScanned > 0) && action != mcActionIdle)
	   || curTime.timeValue != mydoc->prevActionTime.timeValue
	){
		fprintf( stderr, "Stepped:%d Scanned:%d action=%d t=%ss\n", mydoc->wasStepped, mydoc->wasScanned, action,
			   [ QTStringFromTime(curTime) fileSystemRepresentation ]
		);
	}
#endif
	switch( action ){
			case mcActionControllerSizeChanged:
			case mcActionActivate:
			case mcActionDeactivate:
			case mcActionSetPlaySelection:
			case mcActionMouseDown:
			case mcActionMovieClick:
			case mcActionSuspend:
			case mcActionResume:
			case mcActionMovieFinished:
#ifdef DEBUG
				if( mydoc->wasStepped > 0 || mydoc->wasScanned > 0 ){
					fprintf( stderr, "resetting Stepped:%d Scanned:%d action=%d\n", mydoc->wasStepped, mydoc->wasScanned, action );
				}
#endif
				mydoc->wasStepped = FALSE;
				mydoc->wasScanned = FALSE;
				break;
	}
	switch( action ){
		case mcActionMovieLoadStateChanged:
			// params==kMovieLoadStateComplete when streaming video has been received completely?
			mcFeedBack( mydoc, "LoadStateChanged" );
			break;
		case mcActionIdle:
#if DEBUG == 2
			mcFeedBack(mydoc, "Idle");
#elif defined(DEBUG)
			if( mydoc->wasScanned > 0 || mydoc->wasStepped > 0 )
			{
				mcFeedBack( mydoc, "Idle" );
			}
#endif
			if(  mydoc->InfoDrawer== NSDrawerOpenState ){
				if( mydoc->Playing== -1 ){
					mydoc->Playing= ([[mydoc getMovie] rate]> 1e-5)? 1 : NO;
				}
				if( mydoc->Playing ){
					[mydoc setTimeDisplay];
//					[mydoc setRateDisplay];
				}
			}
			break;
		case mcActionStep:
			mydoc->wasStepped = TRUE;
#ifdef DEBUG
			mcFeedBack( mydoc, "Step" );
#endif
			[mydoc setTimeDisplay];
//			[mydoc setRateDisplay];
			// RJVB 20070920: hook to finding the frame time in the EDF data here.
			// determine if a matching EDF filename exists when opening a movie
			// if so, activate the play all frames option
			break;
		case mcActionPlay:{
		  int rate= (int) ([[mydoc getMovie] rate]*1e5);
#ifdef DEBUG
			if( mydoc->wasStepped > 0 ){
				fprintf( stderr, "Movie was STEPPED!\n" );
			}
			else if( mydoc->wasScanned > 0 ){
				fprintf( stderr, "Movie was SCANNED!\n" );
			}
			mcFeedBack( mydoc, "Play" );
#endif
			if( mydoc->wasStepped > 0 ){
				// this is to prevent the upcoming GoToTime action to be taken for a user-scan event.
				mydoc->wasStepped = -1;
			}
			mydoc->wasScanned = FALSE;
			[mydoc UpdateDrawer];
			mydoc->Playing= (rate==0)? -1 : NO;
			break;
		}
		case mcActionActivate:{
#ifdef DEBUG
			mcFeedBack( mydoc, "Activate" );
#endif
			[mydoc setRateDisplay];
			[mydoc updateMenus];
			break;
		}
#ifdef DEBUG
		case mcActionDeactivate:
			mcFeedBack( mydoc, "Deactivate" );
			break;
		case mcActionGoToTime:
			if( !mydoc->wasStepped ){
				mydoc->wasScanned = TRUE;
			}
			mcFeedBack( mydoc, "GoToTime" );
			if( mydoc->wasStepped < 0 ){
				mydoc->wasStepped = FALSE;
			}
			break;
		case mcActionSetPlaySelection:
			mcFeedBack( mydoc, "SetPlaySelection" );
			break;
#endif
		case mcActionMouseDown:
#ifdef DEBUG
			NSLog( @"MouseDown %@, rate=%g", [mydoc getMovie], (double)[[mydoc getMovie] rate] );
#endif
			if( [[mydoc getMovie] rate]< 1e-5 ){
				mydoc->Playing= NO;
			}
			break;
		case mcActionMovieClick:
#ifdef DEBUG
			NSLog( @"MovieClick %@, rate=%g", [mydoc getMovie], (double)[[mydoc getMovie] rate] );
#endif
			if( [[mydoc getMovie] rate]< 1e-5 ){
				mydoc->Playing= NO;
			}
			[mydoc setRateDisplay];
			break;
		case mcActionKeyUp:{
		  EventRecord *evt = (EventRecord*) params;
		  ComponentResult ret;
			evt->message &= charCodeMask;
			switch( evt->message ){
				case 'C':
					ret = MCGetVisible(mc);
					ret = MCSetVisible( mc, !ret );
					break;
				case 'I':
					ShowMovieInformation( [[mydoc getMovie] quickTimeMovie], nothing, 0 );
					break;
				case 'Q':
					[[[mydoc getView] window] performClose:[[mydoc getView] window]];
					[mydoc close];
					break;
			}
			mcFeedBack( mydoc, "KeyUp" );
			break;
		}
		case mcActionSuspend:
			mcFeedBack( mydoc, "Suspend" );
			break;
		case mcActionResume:
			mcFeedBack( mydoc, "Resume" );
			[mydoc setRateDisplay];
			break;
		case mcActionMovieFinished:
#ifdef DEBUG
			MCSetMovieTime( [[mydoc getMovie] quickTimeMovie], mc, GetMovieDuration([[mydoc getMovie] quickTimeMovie])/2 );
#endif // DEBUG
			mcFeedBack( mydoc, "MovieFinished" );
			mydoc->Playing= NO;
			break;
		default:
#if DEBUG == 2
			if( action!= mcActionIdle ){
				NSLog( @"action #%hd refCon=%p", action, refCon );
			}
#endif
			break;
	}
#ifdef DEBUG
	mydoc->prevActionTime = curTime;
#endif
	return false;
}

