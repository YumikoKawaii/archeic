export type View =
  | { kind: "home" }
  | { kind: "library" }
  | { kind: "browse" }
  | { kind: "category"; id: string }
  | { kind: "collection"; id: string };
