import { Icon, type IconName } from "../components";
import type { View } from "../lib/view";

interface Props {
  view: View;
  busy: boolean;
  uploadLabel: string;
  onNavigate: (v: View) => void;
  onUpload: (files: FileList | null) => void;
}

const tabs: [View["kind"], IconName, string][] = [
  ["home", "home", "Home"],
  ["library", "library", "Library"],
  ["browse", "collections", "Collections"],
];

export default function TabBar({ view, busy, uploadLabel, onNavigate, onUpload }: Props) {
  const current = view.kind === "category" || view.kind === "collection" ? "browse" : view.kind;

  return (
    <>
      <label className={busy ? "fab busy" : "fab"} aria-label={uploadLabel}>
        {busy ? <span className="spinner" aria-hidden="true" /> : <Icon name="plus" size={26} />}
        <input
          id="upload-tab"
          type="file"
          multiple
          accept="image/*,video/*"
          hidden
          disabled={busy}
          onChange={(e) => {
            onUpload(e.target.files);
            e.target.value = "";
          }}
        />
      </label>
      <nav className="tabbar" aria-label="Main">
        {tabs.map(([kind, icon, label]) => (
          <button
            key={kind}
            type="button"
            className={current === kind ? "tab on" : "tab"}
            onClick={() => onNavigate({ kind } as View)}
          >
            <Icon name={icon} />
            <span>{label}</span>
          </button>
        ))}
      </nav>
    </>
  );
}
