//
//  BWViewController.h
//  BWDemo
//
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>

@interface BWViewController : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property(nonatomic, strong) AVAsset *videoAsset;
@property(nonatomic, strong) AVAsset *overlayAsset;

@end
