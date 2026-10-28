import { Icon } from "../components";
import type { View } from "../lib/view";

interface Props {
  view: View;
  busy: boolean;
  uploadLabel: string;
  onNavigate: (v: View) => void;
  onUpload: (files: FileList | null) => void;
}

export default function TabBar({ view, busy, uploadLabel, onNavigate, onUpload }: Props) {
  const inLibrary = view.kind === "library";

  return (
    <nav className="tabbar" aria-label="Main">
      <button type="button" className={inLibrary ? "tab on" : "tab"} onClick={() => onNavigate({ kind: "library" })}>
        <Icon name="library" />
        <span>Library</span>
      </button>
      <label className={busy ? "tab-upload busy" : "tab-upload"} aria-label={uploadLabel}>
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
      <button type="button" className={!inLibrary ? "tab on" : "tab"} onClick={() => onNavigate({ kind: "browse" })}>
        <Icon name="collections" />
        <span>Collections</span>
      </button>
    </nav>
  );
}
