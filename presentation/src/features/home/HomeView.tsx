import { useEffect, useState } from "react";
import { timestampDate } from "@bufbuild/protobuf/wkt";
import { contentUrl, Kind, listCategories, listCollections, listMedia, type Collection, type Media } from "../../api/client";
import { Icon, Thumb } from "../../components";
import { run } from "../../lib/notify";
import type { View } from "../../lib/view";
import CollectionCard from "../collection/CollectionCard";

interface Props {
  version: number;
  onNavigate: (v: View) => void;
}

export default function HomeView({ version, onNavigate }: Props) {
  const [media, setMedia] = useState<Media[]>([]);
  const [collections, setCollections] = useState<Collection[]>([]);
  const [spot, setSpot] = useState(0);

  useEffect(() => {
    run(async () => {
      setMedia(await listMedia());
      const cats = await listCategories();
      const all = await Promise.all(cats.map((c) => listCollections(c.id)));
      setCollections(all.flat());
    });
  }, [version]);

  const photos = media.filter((m) => m.kind === Kind.IMAGE);

  useEffect(() => {
    if (photos.length < 2) return;
    const t = setInterval(() => setSpot((s) => (s + 1) % photos.length), 6000);
    return () => clearInterval(t);
  }, [photos.length]);

  const featured = photos.slice(0, 6);
  const videos = media.length - photos.length;
  const since = media.length && media[media.length - 1].createTime ? timestampDate(media[media.length - 1].createTime!).getFullYear() : undefined;
  const hello = greeting(new Date().getHours());

  return (
    <section className="home">
      <header className="hero">
        {featured.length > 0 ? (
          featured.map((m, i) => (
            <img key={m.id} className={i === spot % featured.length ? "hero-img on" : "hero-img"} src={contentUrl(m.id)} alt="" draggable={false} />
          ))
        ) : (
          <div className="hero-aurora" aria-hidden="true" />
        )}
        <div className="hero-shade" aria-hidden="true" />
        <div className="hero-text">
          <span className="eyebrow">{hello}</span>
          <h1 className="wordmark">archeic</h1>
          <p className="hero-stats">
            <b>{photos.length}</b> photos <i /> <b>{videos}</b> videos <i /> <b>{collections.length}</b> collections
          </p>
          {since && <p className="hero-since">Archiving since {since}</p>}
        </div>
        {featured.length > 1 && (
          <div className="hero-dots" aria-hidden="true">
            {featured.map((m, i) => (
              <span key={m.id} className={i === spot % featured.length ? "on" : ""} />
            ))}
          </div>
        )}
      </header>

      <div className="home-actions">
        <button type="button" className="glass-card" onClick={() => onNavigate({ kind: "library" })}>
          <Icon name="library" />
          <span><b>Library</b><small>{media.length} items</small></span>
        </button>
        <button type="button" className="glass-card" onClick={() => onNavigate({ kind: "browse" })}>
          <Icon name="collections" />
          <span><b>Collections</b><small>{collections.length} albums</small></span>
        </button>
      </div>

      {media.length > 0 && (
        <section className="home-sec">
          <button type="button" className="sec-head" onClick={() => onNavigate({ kind: "library" })}>
            <h2>Recently added</h2>
            <Icon name="chevron" size={18} />
          </button>
          <div className="mosaic">
            {media.slice(0, 7).map((m, i) => (
              <button key={m.id} type="button" className={i === 0 ? "tile big" : "tile"} onClick={() => onNavigate({ kind: "library" })}>
                <Thumb media={m} />
                {m.kind === Kind.VIDEO && <span className="tile-badge"><Icon name="play" size={12} /></span>}
              </button>
            ))}
          </div>
        </section>
      )}

      {collections.length > 0 && (
        <section className="home-sec">
          <button type="button" className="sec-head" onClick={() => onNavigate({ kind: "browse" })}>
            <h2>Collections</h2>
            <Icon name="chevron" size={18} />
          </button>
          <div className="scroller">
            {collections.map((c) => (
              <CollectionCard key={c.id} c={c} version={version} onOpen={() => onNavigate({ kind: "collection", id: c.id })} />
            ))}
          </div>
        </section>
      )}
    </section>
  );
}

function greeting(h: number): string {
  if (h < 5) return "Late night";
  if (h < 12) return "Good morning";
  if (h < 18) return "Good afternoon";
  return "Good evening";
}
