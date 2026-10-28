import { useEffect, useState } from "react";
import { listCategories, type Category, type Collection } from "../../api/client";
import { Sheet } from "../../components";
import { run } from "../../lib/notify";
import CollectionTree from "./CollectionTree";

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
    <Sheet title={`Add ${count} ${count === 1 ? "item" : "items"} to…`} onClose={onClose}>
      <div className="picker">
        {categories.map((c) => (
          <section key={c.id}>
            <h3>{c.name}</h3>
            <CollectionTree categoryId={c.id} depth={0} version={0} onOpen={onPick} />
          </section>
        ))}
        {categories.length === 0 && <p className="muted">Create a category and a collection in the Collections tab first.</p>}
      </div>
    </Sheet>
  );
}
