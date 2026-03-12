import Lightbox from 'yet-another-react-lightbox'
import Zoom from 'yet-another-react-lightbox/plugins/zoom'
import 'yet-another-react-lightbox/styles.css'

export type PreviewSlide = {
  id: string
  src: string
  alt: string
  title: string
  description?: string
}

type ImagePreviewLightboxProps = {
  openIndex: number
  slides: PreviewSlide[]
  onClose: () => void
}

export function ImagePreviewLightbox({ openIndex, slides, onClose }: ImagePreviewLightboxProps) {
  return (
    <Lightbox
      open={openIndex >= 0}
      close={onClose}
      index={openIndex < 0 ? 0 : openIndex}
      slides={slides}
      plugins={[Zoom]}
      className="image-lightbox"
      carousel={{
        finite: slides.length <= 1,
        padding: 100,
        spacing: '4%',
      }}
      controller={{ closeOnBackdropClick: true }}
      zoom={{
        maxZoomPixelRatio: 4,
        scrollToZoom: true,
        keyboardMoveDistance: 80,
      }}
      labels={{
        Close: '关闭',
        Previous: '上一张',
        Next: '下一张',
        'Zoom in': '放大',
        'Zoom out': '缩小',
      }}
      render={{
        slideFooter: ({ slide }) => (
          <div
            className="image-lightbox-footer"
            onPointerDown={(event) => event.stopPropagation()}
            onMouseDown={(event) => event.stopPropagation()}
          >
            <strong>{(slide as PreviewSlide).title ?? '图片预览'}</strong>
            <span>{(slide as PreviewSlide).description ?? '滚轮缩放，拖拽查看细节'}</span>
          </div>
        ),
      }}
    />
  )
}
