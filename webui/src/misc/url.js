export const encodeURIComponent = string => string
  .replace('%', '%25')
  .replace('&', '%26')
  .replace('/', '%2F')
  .replace('=', '%3D');

export const decodeURIComponent = string => string
  .replace('%25', '%')
  .replace('%26', '&')
  .replace('%2F', '/')
  .replace('%3D', '=');

export function getSearchParams(search) {
  return search
    ? (
      (search.startsWith('?') ? search.substr(1) : search).split('&').reduce((query, part) => {
        const pair = part.split('=');
        query[decodeURIComponent(pair[0])] = pair.length === 1 ? '' : decodeURIComponent(pair[1]);
        return query
      }, {})
    )
    : {};
}

export function addSearchParams(search, params, castrated) {
  const parsed = getSearchParams(search);
  Object.entries(params).forEach(([key, value]) => {
    if (value == null) {
      delete parsed[key];
    } else {
      parsed[encodeURIComponent(key)] = encodeURIComponent(value);
    }
  });
  const query = Object.entries(parsed).reduce((parts, entry) => {
    parts.push(entry.join('='));
    return parts;
  }, []).join('&');
  return query
    ? castrated ? query : `?${query}`
    : '';
}
