type History = {
  push: (url: string | { search: string }) => void,
}

type Location = {
  search: string,
  href: string,
}
