const { tarantool_enterprise_core } = window;

if (!Element.prototype.matches) {
  Element.prototype.matches = Element.prototype.msMatchesSelector || Element.prototype.webkitMatchesSelector;
}

if (!Element.prototype.closest) {
  Element.prototype.closest = function (s) {
    var el = this;

    do {
      if (el.matches(s)) return el;
      el = el.parentElement || el.parentNode;
    } while (el !== null && el.nodeType === 1);
    return null;
  };
}

const isButton = el => el.tagName === 'BUTTON'

const isLink = el => el.tagName === 'A' || !!el.closest('a')

const metaClassNameSearch = /meta/

const getMetaClassName = el => {
  const classList = el.classList
  for (let i = 0; i < classList.length; i++) {
    const className = classList.item(i)
    if (className.match(metaClassNameSearch)) {
      return className
    }
  }
  return null
}

window.addEventListener('click', e => {
  const target = e.target
  if (isButton(target)) {
    const metaClass = getMetaClassName(target)
    if (metaClass) {
      tarantool_enterprise_core.analyticModule.sendEvent({
        type: 'action',
        action: metaClass,
        category: 'click'
      })
    }
    return
  }
  if (isLink(target)) {
    const link = target.closest('a')
    tarantool_enterprise_core.analyticModule.sendEvent({
      type: 'action',
      action: link.getAttribute('href'),
      category: 'link'
    })
    return
  }
}, true)
