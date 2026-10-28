import { useEffect, useState } from "react";
import { Kind, listMedia, type Collection, type Media } from "../../api/client";
import { Icon, Thumb } from "../../components";
import { run } from "../../lib/notify";

export default function CollectionCard({ c, version, onOpen }: { c: Collection; version: number; onOpen: () => void }) {
  const [items, setItems] = useState<Media[]>([]);

  useEffect(() => {
    run(async () => setItems(await listMedia(Kind.UNSPECIFIED, c.id)));
  }, [c.id, version]);

  const cover = items.find((m) => m.id === c.coverId) ?? items[0];

  return (
    <button type="button" className="card" onClick={onOpen}>
      <div className="cover">
        {cover ? <Thumb media={cover} /> : <span className="blank"><Icon name="image" size={28} /></span>}
      </div>
      <b>{c.name}</b>
      <small>{items.length} {items.length === 1 ? "item" : "items"}</small>
    </button>
  );
}
