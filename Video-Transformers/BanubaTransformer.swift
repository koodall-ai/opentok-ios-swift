import Foundation
import OpenTok
import BNBSdkCore
import BNBSdkApi

let kClientToken = <#Client Token#>

class BanubaTransformer: NSObject, OTCustomVideoTransformer {
    
    public override init() {
    
        if !BanubaTransformer.intialized {
            var resourcePaths = [
                Bundle.main.bundlePath + "/bnb-resources",
                Bundle.main.bundlePath + "/effects",
            ]
            for f in Bundle.allFrameworks {
                if let b = f.bundleIdentifier, b.starts(with: "banuba.sdk.BNB") {
                    resourcePaths.append(f.bundlePath + "/bnb-resources")
                }
            }
            BanubaSdkManager.initialize(resourcePath: resourcePaths, clientTokenString: kClientToken)
            BanubaTransformer.intialized = true
        }
    }
    
    public func loadEffect(name: String) {
        effectName = name
        _ = player?.load(effect: effectName)
    }

    public static func deinitialize() {
        if BanubaTransformer.intialized {
            BanubaSdkManager.deinitialize()
            BanubaTransformer.intialized = false
        }
    }
    
    func transform(_ videoFrame: OTVideoFrame) {
        self.lastVideoFrame = videoFrame

        if player == nil {
            input = BNBSdkApi.Stream()
            output = BNBSdkApi.PixelBufferYUV(onPresent: {(pixelBuffer) -> Void in
                CVPixelBufferLockBaseAddress(pixelBuffer!, .readOnly)

                guard let frame = self.lastVideoFrame else {return}

                let y = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer!, 0)!.assumingMemoryBound(to: UInt8.self)
                let u = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer!, 1)!.assumingMemoryBound(to: UInt8.self)
                let v = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer!, 2)!.assumingMemoryBound(to: UInt8.self)
                let strideY = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer!, 0)
                let strideU = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer!, 1)
                let strideV = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer!, 2)

                let frameWidth = Int(frame.format?.imageWidth ?? 0)
                let frameHeight = Int(frame.format?.imageHeight ?? 0)
                for h in 0 ..< frameHeight {
                    memcpy(frame.getPlaneBinaryData(0) + h * Int(frame.getPlaneStride(0)), y + strideY * h, frameWidth)
                }
                for h in 0 ..< frameHeight / 2 {
                    memcpy(frame.getPlaneBinaryData(1) + h * Int(frame.getPlaneStride(1)), u + strideU * h, frameWidth / 2)
                    memcpy(frame.getPlaneBinaryData(2) + h * Int(frame.getPlaneStride(2)), v + strideV * h, frameWidth / 2)
                }

                CVPixelBufferUnlockBaseAddress(pixelBuffer!, .readOnly)
            }, pixelFormatType: .k420YpCbCr8PlanarFullRange)

            player = Player()
            _ = player?.load(effect: effectName)
            player?.renderMode = .manual
            player?.use(input: input!, outputs: [output!])
            player?.play()
        }

        var planes = [
            videoFrame.planes?.pointer(at: 0),
            videoFrame.planes?.pointer(at: 1),
            videoFrame.planes?.pointer(at: 2)
        ]
        let width  = Int(videoFrame.format?.imageWidth ?? 0)
        let height = Int(videoFrame.format?.imageHeight ?? 0)
        var widths = [width, width / 2, width / 2]
        var heights = [height, height / 2, height / 2]
        var strides = [
            Int(videoFrame.getPlaneStride(0)),
            Int(videoFrame.getPlaneStride(1)),
            Int(videoFrame.getPlaneStride(2))
        ]

        var otBuffer: CVPixelBuffer?;
        assert(CVPixelBufferCreateWithPlanarBytes(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_420YpCbCr8Planar,
            nil,
            0,
            3,
            &planes,
            &widths,
            &heights,
            &strides,
            nil,
            nil,
            nil,
            &otBuffer
        ) == kCVReturnSuccess)

        input?.push(pixelBuffer: otBuffer!)
        _ = player?.render()
    }

    private var player: BNBSdkApi.Player?
    private var input: BNBSdkApi.Stream?
    private var output: BNBSdkApi.PixelBufferYUV?
    private var lastVideoFrame: OTVideoFrame? = nil

    private var effectName: String = ""
    private static var intialized = false
}
