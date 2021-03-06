//
//  NowPlaying.m
//  Subsonic
//
//  Created by Josh Betz on 3/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NowPlaying.h"
#import "AppDelegate.h"
#import "Song.h"
#import "RSSParser.h"
#import <AVFoundation/AVPlayerItem.h>
#import <AVFoundation/AVPlayer.h>
#import <AVFoundation/AVAudioSession.h>
#import <MediaPlayer/MPVolumeView.h>
#import <MediaPlayer/MPNowPlayingInfoCenter.h>
#import <MediaPlayer/MPMediaItemCollection.h>

@interface NowPlaying ()
@end

@implementation NowPlaying
@synthesize songID, playerItem, playButton, userName, userPassword, serverURL, albumArt, reflectionImage, albumArtID, nextButton, prevButton, volumeSlider, artistListProperty, seek;
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidLoad
{
    
    if ([[songList objectAtIndex:currentIndex] albumArtID] != nil){
        albumArtID = [[songList objectAtIndex:currentIndex] albumArtID];
    }
    NSMutableArray *songArray = [[NSMutableArray array] init];
    for (int i = 0; i < [songList count]; i++){
        [songArray addObject:[songList objectAtIndex:i]];
    }
    songList = songArray;
    
    if(songList.count > 0 && differentAlbum == true) {
        [self buildPlaylist];
        playingSongList = songList;
        NSLog(@"%d", [playingSongList count]);
        NSString *artSize;
        if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2){
            //Retina
            artSize = @"640";
        }
        else {
            //Not Retina
            artSize = @"320";
        }
        
        if (albumArtID != nil) {
            userURL = [NSString stringWithFormat:@"%@&id=%@&size=%@", [AppDelegate getEndpoint:@"getCoverArt"], albumArtID, artSize];
            NSURL *imageURL = [NSURL URLWithString: userURL];
            NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
            UIImage *image = [UIImage imageWithData:imageData]; 
            albumArt.image = image;
            art = image;
            
            NSUInteger reflectionHeight = albumArt.bounds.size.height * 0.65;
            reflectionImage.image = [self reflectedImage:albumArt withHeight:reflectionHeight];
            reflectionImage.alpha = 0.45;
        }
        
        avPlayer = [[AVQueuePlayer alloc] initWithPlayerItem:[itemList objectAtIndex:currentIndex]];

        [self playSong:playButton];
        
        for ( int i=currentIndex+1; i < [itemList count]; i++ )
            [avPlayer insertItem:[itemList objectAtIndex:i] afterItem:nil];
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        [[AVAudioSession sharedInstance] setActive: YES error: nil];
        
        differentAlbum = false;
    }
    else if (differentAlbum == false) {
        if (art != nil){
            albumArt.image = art;
            
            NSUInteger reflectionHeight = albumArt.bounds.size.height * 0.65;
            reflectionImage.image = [self reflectedImage:albumArt withHeight:reflectionHeight];
            reflectionImage.alpha = 0.60;
        }
    }
    MPVolumeView *volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(20,380,280,20)];
    [volumeView sizeToFit];
    [self.view addSubview:volumeView];
    
    //playlistMeth = false;
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    if (avPlayer.rate > 0)
        [playButton setImage:[UIImage imageNamed:@"pause.png"] forState:UIControlStateNormal];
    else
        [playButton setImage:[UIImage imageNamed:@"play.png"] forState:UIControlStateNormal];
    
    // custom back button
    UIButton *backButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 37, 31)];
    [backButton setImage:[UIImage imageNamed:@"back.png"] forState:UIControlStateNormal];
    [backButton addTarget:nil action:@selector(popViewControllerAnimated:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    //Once the view has loaded then we can register to begin recieving controls and we can become the first responder
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    nowPlaying = self;
    [super viewWillDisappear:animated];
    
    //End recieving events
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
}

//Make sure we can recieve remote control events
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    //if it is a remote control event handle it correctly
    if (event.type == UIEventTypeRemoteControl) {
        if (event.subtype == UIEventSubtypeRemoteControlPlay) {
            [self playSong:playButton];
        } else if (event.subtype == UIEventSubtypeRemoteControlPause) {
            [self playSong:playButton];
        } else if (event.subtype == UIEventSubtypeRemoteControlTogglePlayPause) {
            [self playSong:playButton];
        } else if (event.subtype == UIEventSubtypeRemoteControlNextTrack) {
            [self nextSong:nextButton];
        } else if (event.subtype == UIEventSubtypeRemoteControlPreviousTrack) {
            [self prevSong:prevButton];
        }
    }
}

- (void)viewDidUnload
{
    nowPlaying = self;
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Actions

// iOS5 Only
- (void) setMediaInfo {
    Class playingInfoCenter = NSClassFromString(@"MPNowPlayingInfoCenter");
    
    if (playingInfoCenter) {
        MPNowPlayingInfoCenter *center = [MPNowPlayingInfoCenter defaultCenter];
        MPMediaItemArtwork *artwork = nil;
        if( albumArtID != nil) {
            artwork = [[MPMediaItemArtwork alloc] initWithImage:art];
        }
        
        NSDictionary *songInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [[playingSongList objectAtIndex:currentIndex] artistName], MPMediaItemPropertyArtist,
                                  [[playingSongList objectAtIndex:currentIndex] songName], MPMediaItemPropertyTitle,
                                  [[playingSongList objectAtIndex:currentIndex] albumName], MPMediaItemPropertyAlbumTitle,
                                  artwork, MPMediaItemPropertyArtwork,
                                  nil];
        center.nowPlayingInfo = songInfo;
    }
    
    // setup scrobbling
    if (lastfm)
        [self scrobble:NO withID:[[playingSongList objectAtIndex:currentIndex] songID]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:[avPlayer currentItem]];
    
    // setup seek slider
    NSString *durString = [[playingSongList objectAtIndex:currentIndex] songDuration];
    float dur = [durString floatValue];
    NSLog(@"Duration: %@", durString);
    [seek setMaximumValue:dur];
    [seek setThumbImage:[[UIImage alloc] init] forState:UIControlStateNormal];
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTime:) userInfo:nil repeats:YES];
    
    // Update the nav bar label
    UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 4, 224, 36)];
    
    UILabel *artist = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 224, 12)];
    artist.text = [[playingSongList objectAtIndex:currentIndex] artistName];
    artist.textColor = [UIColor grayColor];
    artist.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    artist.backgroundColor = [UIColor clearColor];
    artist.font = [UIFont boldSystemFontOfSize: 12.0f];
    artist.textAlignment = UITextAlignmentCenter;
    [titleBar addSubview:artist];
    
    UILabel *song = [[UILabel alloc] initWithFrame:CGRectMake(0, 12, 224, 12)];
    song.text = [[playingSongList objectAtIndex:currentIndex] songName];
    song.textColor = [UIColor whiteColor];
    song.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    song.backgroundColor = [UIColor clearColor];
    song.font = [UIFont boldSystemFontOfSize: 12.0f];
    song.textAlignment = UITextAlignmentCenter;
    [titleBar addSubview:song];
    
    UILabel *album = [[UILabel alloc] initWithFrame:CGRectMake(0, 24, 224, 12)];
    album.text = [[playingSongList objectAtIndex:currentIndex] albumName];
    album.textColor = [UIColor grayColor];
    album.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    album.backgroundColor = [UIColor clearColor];
    album.font = [UIFont boldSystemFontOfSize: 12.0f];
    album.textAlignment = UITextAlignmentCenter;
    [titleBar addSubview:album];
    
    self.navigationItem.titleView = titleBar;
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    if (lastfm)
        [self scrobble:YES withID:[[playingSongList objectAtIndex:currentIndex] songID]];
    
    [avPlayer advanceToNextItem];
    
    if ([[avPlayer items] count] <= 0) {
        [self.navigationController popToRootViewControllerAnimated:YES];
    } else {
        currentIndex++;
        [self setMediaInfo];
    }
}

- (void)buildPlaylist {
    BOOL noProblems = true;
    if (!playlistMeth && !albumMeth){
        for (int i = 0; i < [[[[[[artistList objectAtIndex:selectedArtistSection] objectAtIndex:selectedArtistIndex] albumList] objectAtIndex:selectedAlbumIndex] songList]count]; i++){
            if ([[[[[[[artistList objectAtIndex:selectedArtistSection] objectAtIndex:selectedArtistIndex] albumList] objectAtIndex:selectedAlbumIndex] songList]objectAtIndex:i]songData] == nil){
                noProblems = false;
                break;
            }
        }
    }
    
    if (!playlistMeth && !albumMeth && noProblems) {
        itemList = [[[[[artistList objectAtIndex:selectedArtistSection] objectAtIndex:selectedArtistIndex] albumList] objectAtIndex:selectedAlbumIndex] songList];
    }
    else {
        queueList = [NSMutableArray array];
        itemList = [NSMutableArray array];
        
        NSString *maxBitRate;
        if ( hqMode )
            maxBitRate = @"160";
        else
            maxBitRate = @"96";
        
        for (int i = 0; i < [songList count]; i++){
            userURL = [NSString stringWithFormat:@"%@&id=%@&maxBitRate=%@", [AppDelegate getEndpoint:@"stream"], [[songList objectAtIndex:i] songID], maxBitRate];
            url = [NSURL URLWithString:userURL];
            [queueList addObject:url];
        }
        
        NSLog(@"%d", [queueList count]);
        for (int i = 0; i < [queueList count]; i++){
            url = [queueList objectAtIndex:i];
            AVPlayerItem *songItem = [AVPlayerItem playerItemWithURL:url];
            [itemList addObject:songItem];
        } 
    }
}

- (IBAction)done:(id)sender
{  
    [self dismissModalViewControllerAnimated:YES];
}

-(IBAction)playSong:(id)sender{
    if ([itemList count] > 0){
        if (avPlayer.rate == 0.0){
            UIBackgroundTaskIdentifier newTaskId = UIBackgroundTaskInvalid;
            [avPlayer play];
            newTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:NULL];
            [playButton setImage:[UIImage imageNamed:@"pause.png"] forState:UIControlStateNormal];
        }   
        else {
            [avPlayer pause];
            [playButton setImage:[UIImage imageNamed:@"play.png"] forState:UIControlStateNormal];
        }
    }
    [self setMediaInfo];
}

-(IBAction)nextSong:(id)nextButton{
    [avPlayer advanceToNextItem];
    currentIndex++;
    [self setMediaInfo];
}

-(IBAction)prevSong:(id)prevButton{
    currentIndex--;
    if( currentIndex < 0 )
        currentIndex = 0;

    UIBackgroundTaskIdentifier newTaskId = UIBackgroundTaskInvalid;
    
    avPlayer = [[AVQueuePlayer alloc] initWithPlayerItem:[AVPlayerItem playerItemWithURL:[queueList objectAtIndex:currentIndex]]];
    [avPlayer play];
    
    if (lastfm)
        [self scrobble:NO withID:[[playingSongList objectAtIndex:currentIndex] songID]];
    
    [self buildPlaylist];
    for ( int i=currentIndex+1; i < [itemList count]; i++ )
        [avPlayer insertItem:[AVPlayerItem playerItemWithURL:[queueList objectAtIndex:i]] afterItem:nil];
    
    newTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:NULL];
}

-(BOOL)scrobble:(BOOL)submission withID:(NSString *)id {
    NSString *scrobbleURL = [NSString stringWithFormat:@"%@&id=%@&submission=%@", [AppDelegate getEndpoint:@"scrobble"], id, (submission ? @"true" : @"false") ];
    RSSParser *parser = [[RSSParser alloc] initWithRSSFeed: scrobbleURL];

    if ( parser != nil )
        return true;

    return false;
}

-(void)adjustVolume
{
    if (avPlayer != nil)
    {
        //[avPlayer set = volumeSlider.value;
    }
}

- (void)updateTime:(NSTimer *)timer {
    [seek setValue:CMTimeGetSeconds([avPlayer currentTime])];
}

#pragma mark - Image Reflection

CGImageRef CreateGradientImage(int pixelsWide, int pixelsHigh)
{
    CGImageRef theCGImage = NULL;
    
    // gradient is always black-white and the mask must be in the gray colorspace
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    
    // create the bitmap context
    CGContextRef gradientBitmapContext = CGBitmapContextCreate(NULL, pixelsWide, pixelsHigh,
                                                               8, 0, colorSpace, kCGImageAlphaNone);
    
    // define the start and end grayscale values (with the alpha, even though
    // our bitmap context doesn't support alpha the gradient requires it)
    CGFloat colors[] = {0.0, 1.0, 1.0, 1.0};
    
    // create the CGGradient and then release the gray color space
    CGGradientRef grayScaleGradient = CGGradientCreateWithColorComponents(colorSpace, colors, NULL, 2);
    CGColorSpaceRelease(colorSpace);
    
    // create the start and end points for the gradient vector (straight down)
    CGPoint gradientStartPoint = CGPointZero;
    CGPoint gradientEndPoint = CGPointMake(0, pixelsHigh);
    
    // draw the gradient into the gray bitmap context
    CGContextDrawLinearGradient(gradientBitmapContext, grayScaleGradient, gradientStartPoint,
                                gradientEndPoint, kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(grayScaleGradient);
    
    // convert the context into a CGImageRef and release the context
    theCGImage = CGBitmapContextCreateImage(gradientBitmapContext);
    CGContextRelease(gradientBitmapContext);
    
    // return the imageref containing the gradient
    return theCGImage;
}

CGContextRef MyCreateBitmapContext(int pixelsWide, int pixelsHigh)
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // create the bitmap context
    CGContextRef bitmapContext = CGBitmapContextCreate (NULL, pixelsWide, pixelsHigh, 8,
                                                        0, colorSpace,
                                                        // this will give us an optimal BGRA format for the device:
                                                        (kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst));
    CGColorSpaceRelease(colorSpace);
    
    return bitmapContext;
}

- (UIImage *)reflectedImage:(UIImageView *)fromImage withHeight:(NSUInteger)height
{
    if(height == 0)
        return nil;
    
    // create a bitmap graphics context the size of the image
    CGContextRef mainViewContentContext = MyCreateBitmapContext(fromImage.bounds.size.width, height);
    
    // create a 2 bit CGImage containing a gradient that will be used for masking the 
    // main view content to create the 'fade' of the reflection.  The CGImageCreateWithMask
    // function will stretch the bitmap image as required, so we can create a 1 pixel wide gradient
    CGImageRef gradientMaskImage = CreateGradientImage(1, height);
    
    // create an image by masking the bitmap of the mainView content with the gradient view
    // then release the  pre-masked content bitmap and the gradient bitmap
    CGContextClipToMask(mainViewContentContext, CGRectMake(0.0, 0.0, fromImage.bounds.size.width, height), gradientMaskImage);
    CGImageRelease(gradientMaskImage);
    
    // In order to grab the part of the image that we want to render, we move the context origin to the
    // height of the image that we want to capture, then we flip the context so that the image draws upside down.
    CGContextTranslateCTM(mainViewContentContext, 0.0, height);
    CGContextScaleCTM(mainViewContentContext, 1.0, -1.0);
    
    // draw the image into the bitmap context
    CGContextDrawImage(mainViewContentContext, fromImage.bounds, fromImage.image.CGImage);
    
    // create CGImageRef of the main view bitmap content, and then release that bitmap context
    CGImageRef reflectedImage = CGBitmapContextCreateImage(mainViewContentContext);
    CGContextRelease(mainViewContentContext);
    
    // convert the finished reflection image to a UIImage 
    UIImage *theImage = [UIImage imageWithCGImage:reflectedImage];
    
    // image is retained by the property setting above, so we can release the original
    CGImageRelease(reflectedImage);
    
    return theImage;
}


@end