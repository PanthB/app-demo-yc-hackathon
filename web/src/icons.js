const PATHS = {
  clip: '<rect x="3" y="5" width="18" height="14" rx="3.5"/><path d="M10.5 9.5v5l4.2-2.5z" fill="currentColor"/>',
  song: '<path d="M9 17.5V6.5l10-2v11"/><circle cx="6.5" cy="17.5" r="2.5"/><circle cx="16.5" cy="15.5" r="2.5"/>',
  place: '<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.3"/>',
  event: '<path d="M4 7.5h16v3a1.8 1.8 0 0 0 0 3.6v3.4H4v-3.4a1.8 1.8 0 0 0 0-3.6z"/><path d="M14.5 7.5v10" stroke-dasharray="1.6 2"/>',
  watch: '<rect x="3" y="6.5" width="18" height="12" rx="2.5"/><path d="M8.5 3l3.5 3.5L15.5 3"/>',
  link: '<path d="M10 14a4 4 0 0 0 5.66 0l3-3a4 4 0 0 0-5.66-5.66l-1 1"/><path d="M14 10a4 4 0 0 0-5.66 0l-3 3a4 4 0 0 0 5.66 5.66l1-1"/>',
  note: '<path d="M6 3.5h8.5L18 7v13.5H6z"/><path d="M9 11.5h6M9 15.5h6"/>',
  photo: '<rect x="3" y="5" width="18" height="14" rx="3.5"/><circle cx="9" cy="10" r="1.7"/><path d="M20.5 16l-4.8-4.8L8 19"/>',
  voice: '<path d="M4 10v4M8 7v10M12 4v16M16 8v8M20 10.5v3"/>',
  reminder: '<circle cx="12" cy="13.5" r="7"/><path d="M12 13.5V10M10 3h4"/>',
};

export function icon(kind) {
  return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + (PATHS[kind] ?? PATHS.link) + "</svg>";
}
