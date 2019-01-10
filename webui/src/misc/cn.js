export function classNameFilter(name) {
  return name != null && typeof name !== 'boolean' && name !== '';
}

export default function cn(...names) {
  return names.filter(classNameFilter).join(' ');
}
