#import "MPAdView.h"
#import "MPAdConfigurationFactory.h"
#import "FakeIMAdView.h"

using namespace Cedar::Matchers;
using namespace Cedar::Doubles;

SPEC_BEGIN(MPInMobiBannerIntegrationSuite)

describe(@"MPInMobiBannerIntegrationSuite", ^{
    __block FakeIMAdView *fakeAd;
    __block MPAdConfiguration *configuration;

    __block MPAdView *banner;
    __block id<CedarDouble, MPAdViewDelegate> delegate;
    __block FakeMPAdServerCommunicator *communicator;

    beforeEach(^{
        delegate = nice_fake_for(@protocol(MPAdViewDelegate));

        configuration = [MPAdConfigurationFactory defaultBannerConfigurationWithCustomEventClassName:@"InMobiBannerCustomEvent"];
    });

    describe(@"with a valid size", ^{
        beforeEach(^{
            fakeAd = [[[FakeIMAdView alloc] init] autorelease];
            fakeProvider.fakeIMAdView = fakeAd;

            banner = [[[MPAdView alloc] initWithAdUnitId:@"inmobi_banner" size:MOPUB_BANNER_SIZE] autorelease];
            banner.delegate = delegate;
            [banner loadAd];

            communicator = fakeProvider.lastFakeMPAdServerCommunicator;
            [communicator receiveConfiguration:configuration];
        });

        it(@"should ask the ad to load and configure it correctly", ^{
            fakeAd.loadedRequest should_not be_nil;
            fakeAd.frame.size should equal(MOPUB_BANNER_SIZE);
        });

        context(@"when the ad loads succesfully", ^{
            beforeEach(^{
                [delegate reset_sent_messages];
                [fakeAd simulateLoadingAd];
            });

            it(@"should tell the delegate, show the ad, and track an impression", ^{
                verify_fake_received_selectors(delegate, @[@"adViewDidLoadAd:"]);
                banner.subviews should equal(@[fakeAd]);
                banner.adContentViewSize should equal(fakeAd.frame.size);
                fakeProvider.sharedFakeMPAnalyticsTracker.trackedImpressionConfigurations should equal(@[configuration]);
            });

            context(@"when the user taps the ad", ^{
                beforeEach(^{
                    [delegate reset_sent_messages];
                    [fakeAd simulateUserTap];
                });

                it(@"should tell the delegate and track a click (just once)", ^{
                    verify_fake_received_selectors(delegate, @[@"willPresentModalViewForAd:"]);
                    fakeProvider.sharedFakeMPAnalyticsTracker.trackedClickConfigurations should equal(@[configuration]);

                    [fakeAd simulateUserTap];
                    fakeProvider.sharedFakeMPAnalyticsTracker.trackedClickConfigurations should equal(@[configuration]);
                });

                context(@"when the user dismisses the modal", ^{
                    beforeEach(^{
                        [delegate reset_sent_messages];
                        [fakeAd simulateUserEndingInteraction];
                    });

                    it(@"should tell the delegate", ^{
                        verify_fake_received_selectors(delegate, @[@"didDismissModalViewForAd:"]);
                    });
                });

                context(@"when the user leaves the application", ^{
                    beforeEach(^{
                        [delegate reset_sent_messages];
                        [fakeAd simulateUserLeavingApplication];
                    });

                    it(@"should tell the delegate", ^{
                        verify_fake_received_selectors(delegate, @[@"willLeaveApplicationFromAd:"]);
                    });
                });
            });
        });

        context(@"when the ad fails to load", ^{
            beforeEach(^{
                [fakeAd simulateFailingToLoad];
            });

            it(@"should start the waterfall", ^{
                communicator.loadedURL should equal(configuration.failoverURL);
            });
        });
    });

    describe(@"with an invalid size", ^{
        beforeEach(^{
            banner = [[[MPAdView alloc] initWithAdUnitId:@"inmobi_banner" size:CGSizeMake(1,0)] autorelease];
            banner.delegate = delegate;
            [banner loadAd];

            communicator = fakeProvider.lastFakeMPAdServerCommunicator;
            [communicator receiveConfiguration:configuration];
        });

        it(@"should immediately fail and start the waterfall", ^{
            communicator.loadedURL should equal(configuration.failoverURL);
        });
    });
});

SPEC_END
