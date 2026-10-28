import { useEffect, useState } from "react";
import {
  createCollection,
  deleteCollection,
  getCategory,
  getCollection,
  Kind,
  listCollections,
  listMedia,
  type Category,
  type Collection,
  type Media,
} from "../../api/client";
import { ConfirmButton, IconButton, NameForm, Sheet } from "../../components";
import { countLabel } from "../../lib/dates";
import { notify, run } from "../../lib/notify";
import type { View } from "../../lib/view";
import MediaBrowser from "../media/MediaBrowser";
import CollectionCard from "./CollectionCard";

interface Props {
  id: string;
  version: number;
  onNavigate: (v: View) => void;
  onChanged: () => void;
}

export default function CollectionView({ id, version, onNavigate, onChanged }: Props) {
  const [collection, setCollection] = useState<Collection>();
  const [category, setCategory] = useState<Category>();
  const [trail, setTrail] = useState<Collection[]>([]);
  const [children, setChildren] = useState<Collection[]>([]);
  const [items, setItems] = useState<Media[]>([]);
  const [adding, setAdding] = useState(false);

  useEffect(() => {
    run(async () => {
      const c = await getCollection(id);
      if (!c) return;
      const parents: Collection[] = [];
      for (let p = c.parentId; p; ) {
        const parent = await getCollection(p);
        if (!parent) break;
        parents.unshift(parent);
        p = parent.parentId;
      }
      setCollection(c);
      setTrail(parents);
      setCategory(await getCategory(c.categoryId));
      setChildren(await listCollections(c.categoryId, c.id));
      setItems(await listMedia(Kind.UNSPECIFIED, c.id));
    });
  }, [id, version]);

  if (!collection) return null;

  const up: View = collection.parentId
    ? { kind: "collection", id: collection.parentId }
    : { kind: "category", id: collection.categoryId };

  const path = [category?.name, ...trail.map((p) => p.name)].filter(Boolean).join(" / ");

  return (
    <>
      <MediaBrowser
        title={collection.name}
        subtitle={`${path} · ${countLabel(items, Kind.IMAGE)}`}
        back={() => onNavigate(up)}
        items={items}
        collection={collection}
        onChanged={onChanged}
        empty={{
          title: "No media yet",
          text: "Tap + to upload straight into this collection, or select media in the library and add it here.",
        }}
        actions={
          <>
            <IconButton icon="folderPlus" label="New sub-collection" onClick={() => setAdding(true)} />
            <ConfirmButton
              label="Delete"
              icon="trash"
              onConfirm={() =>
                run(async () => {
                  await deleteCollection(id);
                  notify(`Deleted ${collection.name}`);
                  onNavigate(up);
                  onChanged();
                })
              }
            />
          </>
        }
        before={
          children.length > 0 && (
            <div className="scroller">
              {children.map((c) => (
                <CollectionCard key={c.id} c={c} version={version} onOpen={() => onNavigate({ kind: "collection", id: c.id })} />
              ))}
            </div>
          )
        }
      />

      {adding && (
        <Sheet title={`New collection in ${collection.name}`} onClose={() => setAdding(false)}>
          <NameForm
            id="new-sub-collection"
            placeholder="Day 1"
            submit="Create"
            onCancel={() => setAdding(false)}
            onSubmit={(name) =>
              run(async () => {
                await createCollection(collection.categoryId, name, collection.id);
                setAdding(false);
                onChanged();
              })
            }
          />
        </Sheet>
      )}
    </>
  );
}
