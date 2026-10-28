import { useEffect, useState } from "react";
import { Kind, listMedia, type Media } from "../../api/client";
import MediaBrowser from "../../features/media/MediaBrowser";
import { run } from "../../lib/notify";

const filters: [Kind, string][] = [
  [Kind.UNSPECIFIED, "All"],
  [Kind.IMAGE, "Images"],
  [Kind.VIDEO, "Videos"],
];

export default function LibraryView({ version, onChanged }: { version: number; onChanged: () => void }) {
  const [items, setItems] = useState<Media[]>([]);
  const [filter, setFilter] = useState<Kind>(Kind.UNSPECIFIED);

  useEffect(() => {
    run(async () => setItems(await listMedia(filter)));
  }, [filter, version]);

  return (
    <MediaBrowser
      items={items}
      onChanged={onChanged}
      empty="Nothing here yet. Upload images or videos to fill the library."
      toolbar={
        <nav className="tabs">
          {filters.map(([k, label]) => (
            <button key={label} type="button" className={filter === k ? "on" : ""} onClick={() => setFilter(k)}>
              {label}
            </button>
          ))}
        </nav>
      }
    />
  );
}
