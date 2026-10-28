import { useEffect, useState } from "react";
import { Kind, listMedia, type Media } from "../../api/client";
import { Segmented } from "../../components";
import { countLabel } from "../../lib/dates";
import { run } from "../../lib/notify";
import MediaBrowser from "../media/MediaBrowser";

const filters: [Kind, string][] = [
  [Kind.UNSPECIFIED, "All"],
  [Kind.IMAGE, "Photos"],
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
      title="Library"
      subtitle={countLabel(items, Kind.IMAGE)}
      items={items}
      grouped
      onChanged={onChanged}
      filters={<Segmented value={filter} options={filters} onChange={setFilter} />}
      empty={
        filter === Kind.UNSPECIFIED
          ? { title: "Your library is empty", text: "Tap + to upload photos and videos. They are stored as-is, without compression." }
          : { title: `No ${filter === Kind.IMAGE ? "photos" : "videos"}`, text: "Switch to All to see everything else." }
      }
    />
  );
}
