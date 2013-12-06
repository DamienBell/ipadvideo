//
//  BWViewController.m
//  BWDemo
//
//

#import "BWViewController.h"

@interface BWViewController () {
    IBOutlet UIScrollView * _scrollView;
	IBOutlet UILabel * _label;
    CGSize movieDimensions;
    NSTimeInterval movieDuration;
}

@property (nonatomic, strong) MPMoviePlayerController * moviePlayer;
@property (nonatomic, strong) NSString * moviePath;

@end

@implementation BWViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	_label.text = @"No movie.";
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Button Actions

- (IBAction)cameraButton:(id)sender {
	[self startCameraControllerFromViewController:self usingDelegate:self];
}

- (IBAction)saveMovieButton:(id)sender {
	if(UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(self.moviePath)) {
		_label.text = @"Saving movie...";

		UISaveVideoAtPathToSavedPhotosAlbum(self.moviePath, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
	} else {
		_label.text = @"Cannot save movie.";
	}
}

// reset the movie player
- (void) resetMoviePlayer {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MPMovieNaturalSizeAvailableNotification object:self.moviePlayer];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MPMovieDurationAvailableNotification object:self.moviePlayer];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:self.moviePlayer];
	if ([_scrollView.subviews count]) [_scrollView.subviews[0] removeFromSuperview];
	if (self.moviePlayer) self.moviePlayer = nil;
	movieDuration = 0;
	movieDimensions.width = movieDimensions.height = 0;
}

#pragma mark - Save video callbacks

- (void) video:(NSString *) path didFinishSavingWithError:(NSError *)error contextInfo:(void *) contextInfo {
	if(error) {
		_label.text = [NSString stringWithFormat:@"Error %d: %@", error.code, error.localizedDescription];
	} else {
		_label.text = @"Movie saved.";
		[self resetMoviePlayer];
        
        //should I combine them here?
	}
}

#pragma mark - UIImagePickerControllerDelegate methods

- (BOOL) startCameraControllerFromViewController: (UIViewController*) controller usingDelegate: (id <UIImagePickerControllerDelegate, UINavigationControllerDelegate>) delegate {
	if (([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera] == NO) || (delegate == nil) || (controller == nil))
		return NO;
	
	UIImagePickerController *cameraUI = [[UIImagePickerController alloc] init];
    
	cameraUI.mediaTypes = [NSArray arrayWithObject:(NSString *)kUTTypeMovie];
	
	cameraUI.sourceType = UIImagePickerControllerSourceTypeCamera;
	cameraUI.cameraCaptureMode = UIImagePickerControllerCameraCaptureModeVideo;
	cameraUI.videoQuality = UIImagePickerControllerQualityTypeMedium;
	
	cameraUI.delegate = delegate;
	[controller presentViewController:cameraUI animated:YES completion:nil];
	return YES;
}

- (void) imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    NSLog(@"didFinishPickingMediaWithInfo");
    
	[self dismissViewControllerAnimated:YES completion:^{
        
		[self resetMoviePlayer];
		
		_label.text = @"Have movie.";
		
		NSURL *movieURL = info[UIImagePickerControllerMediaURL];
		self.moviePath = [movieURL path];
         self.videoAsset = [AVAsset assetWithURL:movieURL];
        [self videoOutput];

	}];
}


- (void) imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - MPMoviePlayerController notification callbacks

- (void) moviePlaybackFinishedCallback: (NSNotification * ) notification {
    NSLog(@"moviePlaybackFinishedCallback");
	[self.moviePlayer prepareToPlay];
}

- (void) movieDimensionsCallback: (NSNotification *) notification {
	MPMoviePlayerController * moviePlayer = notification.object;
	if(moviePlayer.naturalSize.width > 0) movieDimensions = moviePlayer.naturalSize;
	if(moviePlayer.duration > 0) movieDuration = moviePlayer.duration;
	_label.text = [NSString stringWithFormat:@"Have movie: %d x %d, %f sec", (int) movieDimensions.width, (int) movieDimensions.height, movieDuration];
}

#pragma mark - AVMutableVideoComposition 'pulled from tutorial'

- (void)applyVideoEffectsToComposition:(AVMutableVideoComposition *)composition size:(CGSize)size
{
    NSLog(@"applyVideoEffectsToComposition");

    // 1 - set up the overlay
    CALayer *overlayLayer = [CALayer layer];
    UIImage *overlayImage = [UIImage imageNamed:@"overlay.png"];
    [overlayLayer setContents:(id)[overlayImage CGImage]];
    overlayLayer.frame = CGRectMake(0, 0, 316, 61);
    [overlayLayer setMasksToBounds:YES];
    
    // 2 - set up the parent layer
    CALayer *parentLayer = [CALayer layer];
    CALayer *videoLayer = [CALayer layer];
    parentLayer.frame = CGRectMake(0, 0, size.width, size.height);
    videoLayer.frame = CGRectMake(0, 0, size.width, size.height);
    [parentLayer addSublayer:videoLayer];
    [parentLayer addSublayer:overlayLayer];
    
    // 3 - apply magic
    composition.animationTool = [AVVideoCompositionCoreAnimationTool
                                 videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
    
}
- (void)videoOutput
{
    // 1 - Early exit if there's no video file selected
    if (!self.videoAsset) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please Load a Video Asset First"
                                                       delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    // 2 - Create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    
    // 3 - Video track
    AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
    [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, self.videoAsset.duration)
                        ofTrack:[[self.videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                         atTime:kCMTimeZero error:nil];
    
    // 3.1 - Create AVMutableVideoCompositionInstruction
    AVMutableVideoCompositionInstruction *mainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, self.videoAsset.duration);
    
    // 3.2 - Create an AVMutableVideoCompositionLayerInstruction for the video track and fix the orientation.
    AVMutableVideoCompositionLayerInstruction *videolayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    AVAssetTrack *videoAssetTrack = [[self.videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    UIImageOrientation videoAssetOrientation_  = UIImageOrientationUp;
    BOOL isVideoAssetPortrait_  = NO;
    CGAffineTransform videoTransform = videoAssetTrack.preferredTransform;
    if (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0) {
        videoAssetOrientation_ = UIImageOrientationRight;
        isVideoAssetPortrait_ = YES;
    }
    if (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0) {
        videoAssetOrientation_ =  UIImageOrientationLeft;
        isVideoAssetPortrait_ = YES;
    }
    if (videoTransform.a == 1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == 1.0) {
        videoAssetOrientation_ =  UIImageOrientationUp;
    }
    if (videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0) {
        videoAssetOrientation_ = UIImageOrientationDown;
    }
    [videolayerInstruction setTransform:videoAssetTrack.preferredTransform atTime:kCMTimeZero];
    [videolayerInstruction setOpacity:0.0 atTime:self.videoAsset.duration];
    
    // 3.3 - Add instructions
    mainInstruction.layerInstructions = [NSArray arrayWithObjects:videolayerInstruction,nil];
    
    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
    
    CGSize naturalSize;
    if(isVideoAssetPortrait_){
        naturalSize = CGSizeMake(videoAssetTrack.naturalSize.height, videoAssetTrack.naturalSize.width);
    } else {
        naturalSize = videoAssetTrack.naturalSize;
    }
    
    float renderWidth, renderHeight;
    renderWidth = naturalSize.width;
    renderHeight = naturalSize.height;
    mainCompositionInst.renderSize = CGSizeMake(renderWidth, renderHeight);
    mainCompositionInst.instructions = [NSArray arrayWithObject:mainInstruction];
    mainCompositionInst.frameDuration = CMTimeMake(1, 30);
    
    [self applyVideoEffectsToComposition:mainCompositionInst size:naturalSize];
    
    // 4 - Get path
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *myPathDocs =  [documentsDirectory stringByAppendingPathComponent:
                             [NSString stringWithFormat:@"FinalVideo-%d.mov",arc4random() % 1000]];
    NSURL *url = [NSURL fileURLWithPath:myPathDocs];
    
    // 5 - Create exporter
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition
                                                                      presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL=url;
    exporter.outputFileType = AVFileTypeQuickTimeMovie;
    exporter.shouldOptimizeForNetworkUse = YES;
    exporter.videoComposition = mainCompositionInst;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self exportDidFinish:exporter];
        });
    }];
}


- (void)exportDidFinish:(AVAssetExportSession*)session {
    
    NSLog(@"exportDidFinish");
    
    if (session.status == AVAssetExportSessionStatusCompleted) {
        NSURL *outputURL = session.outputURL;
        [self addMovieToScrollView:outputURL];
        
        //set the moviePath to our new composed url
        self.moviePath= [outputURL path];
    }
}


#pragma mark - custom functions

-(void)addMovieToScrollView:(NSURL *)movieURL{
    
    self.moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:movieURL];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieDimensionsCallback:) name:MPMovieNaturalSizeAvailableNotification object:self.moviePlayer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieDimensionsCallback:) name:MPMovieDurationAvailableNotification object:self.moviePlayer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlaybackFinishedCallback:) name:MPMoviePlayerPlaybackDidFinishNotification object:self.moviePlayer];
    
    self.moviePlayer.movieSourceType = MPMovieSourceTypeFile;
    self.moviePlayer.view.frame = _scrollView.bounds;
    self.moviePlayer.shouldAutoplay = NO;
    
    [_scrollView addSubview:self.moviePlayer.view];
    [self.moviePlayer prepareToPlay];
}

@end
