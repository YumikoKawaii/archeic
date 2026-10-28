import { useEffect, type ReactNode } from "react";
import { contentUrl, Kind, type Media } from "../../api/client";
import { ConfirmButton, Icon } from "../../components";
import ZoomImage from "./ZoomImage";

interface Props {
  media: Media;
  index: number;
  count: number;
  extra?: ReactNode;
  onClose: () => void;
  onPrev: () => void;
  onNext: () => void;
  onDelete: () => void;
}

export default function Viewer({ media, index, count, extra, onClose, onPrev, onNext, onDelete }: Props) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
      if (e.key === "ArrowLeft") onPrev();
      if (e.key === "ArrowRight") onNext();
    };
    window.addEventListener("keydown", onKey);
    document.body.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = "";
    };
  }, [onClose, onPrev, onNext]);

  return (
    <div className="viewer" role="dialog" aria-label={media.name}>
      <div className="v-top">
        <button type="button" className="icon-btn" aria-label="Close" onClick={onClose}>
          <Icon name="close" />
        </button>
        <div className="v-title">
          <b>{media.name}</b>
          <small>{index + 1} of {count}</small>
        </div>
        <a className="icon-btn" href={contentUrl(media.id)} download={media.name} aria-label="Download">
          <Icon name="download" />
        </a>
      </div>

      <div className="stage">
        {media.kind === Kind.IMAGE ? (
          <ZoomImage
            key={media.id}
            src={contentUrl(media.id)}
            alt={media.name}
            onSwipe={(dir) => (dir === "left" ? onNext() : dir === "right" ? onPrev() : onClose())}
          />
        ) : (
          <video key={media.id} src={contentUrl(media.id)} controls autoPlay playsInline />
        )}
      </div>

      <div className="v-bottom">
        <button type="button" aria-label="Previous" onClick={onPrev}>
          <Icon name="back" />
        </button>
        {extra}
        <ConfirmButton label="Delete" icon="trash" onConfirm={onDelete} />
        <button type="button" aria-label="Next" onClick={onNext}>
          <Icon name="chevron" />
        </button>
      </div>
    </div>
  );
}
