import { useEffect, type ReactNode } from "react";
import { contentUrl, Kind, type Media } from "../../api/client";
import { ConfirmButton } from "../../components";
import ZoomImage from "./ZoomImage";

interface Props {
  media: Media;
  extra?: ReactNode;
  onClose: () => void;
  onPrev: () => void;
  onNext: () => void;
  onDelete: () => void;
}

export default function Viewer({ media, extra, onClose, onPrev, onNext, onDelete }: Props) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
      if (e.key === "ArrowLeft") onPrev();
      if (e.key === "ArrowRight") onNext();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose, onPrev, onNext]);

  return (
    <div className="viewer" onClick={onClose}>
      <div className="stage" onClick={(e) => e.stopPropagation()}>
        {media.kind === Kind.IMAGE ? (
          <ZoomImage key={media.id} src={contentUrl(media.id)} alt={media.name} />
        ) : (
          <video key={media.id} src={contentUrl(media.id)} controls autoPlay />
        )}
      </div>
      <div className="bar" onClick={(e) => e.stopPropagation()}>
        <button type="button" aria-label="Previous" onClick={onPrev}>‹</button>
        <span>{media.name}</span>
        {extra}
        <a href={contentUrl(media.id)} download={media.name}>Download</a>
        <ConfirmButton label="Delete" onConfirm={onDelete} />
        <button type="button" aria-label="Close" onClick={onClose}>Close</button>
        <button type="button" aria-label="Next" onClick={onNext}>›</button>
      </div>
    </div>
  );
}
