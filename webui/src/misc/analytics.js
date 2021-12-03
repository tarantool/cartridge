import { core } from '@tarantool.io/frontend-core';

if (!Element.prototype.matches) {
  Element.prototype.matches = Element.prototype.msMatchesSelector || Element.prototype.webkitMatchesSelector;
}

if (!Element.prototype.closest) {
  Element.prototype.closest = function (s) {
    // eslint-disable-next-line @typescript-eslint/no-this-alias
    var el = this;

    do {
      if (el.matches(s)) return el;
      el = el.parentElement || el.parentNode;
    } while (el !== null && el.nodeType === 1);
    return null;
  };
}

const isButton = (el) => el.tagName === 'BUTTON' || !!el.closest('button');

const isLink = (el) => el.tagName === 'A' || !!el.closest('a');

const metaClassNameSearch = /meta/;

const getMetaClassName = (el) => {
  const classList = el.classList;
  for (let i = 0; i < classList.length; i++) {
    const className = classList.item(i);
    if (className.match(metaClassNameSearch)) {
      return className;
    }
  }
  return null;
};

window.addEventListener(
  'click',
  (e) => {
    const target = e.target;
    if (isButton(target)) {
      const metaClass = getMetaClassName(target);
      if (metaClass) {
        core.analyticModule.sendEvent({
          type: 'action',
          action: metaClass,
          category: 'click',
        });
      }
      return;
    }
    if (isLink(target)) {
      const link = target.closest('a');
      core.analyticModule.sendEvent({
        type: 'action',
        action: link.getAttribute('href'),
        category: 'link',
      });
      // eslint-disable-next-line sonarjs/no-redundant-jump
      return;
    }
  },
  true
);
