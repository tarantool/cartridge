export const subscribeOnTargetEvent = (target, event, handler) => {
  target.addEventListener(event, handler)
  return () => {
    target.removeEventListener(event, handler)
  }
}
