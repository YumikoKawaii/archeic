import { useEffect, useState } from "react";
import { listCategories, type Category, type Collection } from "../../api/client";
import CollectionTree from "./CollectionTree";
import { run } from "../../lib/notify";

interface Props {
  count: number;
  onPick: (c: Collection) => void;
  onClose: () => void;
}

export default function CollectionPicker({ count, onPick, onClose }: Props) {
  const [categories, setCategories] = useState<Category[]>([]);

  useEffect(() => {
    run(async () => setCategories(await listCategories()));
  }, []);

  return (
    <div className="modal" onClick={onClose}>
      <div className="dialog" role="dialog" aria-label="Add to collection" onClick={(e) => e.stopPropagation()}>
        <h2>Add {count} {count === 1 ? "item" : "items"} to a collection</h2>
        <div className="picker">
          {categories.map((c) => (
            <section key={c.id}>
              <h3>{c.name}</h3>
              <CollectionTree categoryId={c.id} depth={0} version={0} onOpen={onPick} />
            </section>
          ))}
          {categories.length === 0 && <p className="muted">Create a category and a collection first.</p>}
        </div>
        <div className="row end">
          <button type="button" onClick={onClose}>Cancel</button>
        </div>
      </div>
    </div>
  );
}
