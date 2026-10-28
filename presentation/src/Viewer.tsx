import { useEffect } from "react";
import { contentUrl, Kind, type Media } from "./api";

interface Props {
  media: Media;
  onClose: () => void;
  onPrev: () => void;
  onNext: () => void;
  onDelete: () => void;
}

export default function Viewer({ media, onClose, onPrev, onNext, onDelete }: Props) {
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
          <img src={contentUrl(media.id)} alt={media.name} />
        ) : (
          <video key={media.id} src={contentUrl(media.id)} controls autoPlay />
        )}
      </div>
      <div className="bar" onClick={(e) => e.stopPropagation()}>
        <button onClick={onPrev}>‹</button>
        <span>{media.name}</span>
        <a href={contentUrl(media.id)} download={media.name}>Download</a>
        <button onClick={onDelete}>Delete</button>
        <button onClick={onNext}>›</button>
      </div>
    </div>
  );
}
