Icon can be static or interactive

### Icon adding guide

Add new icon as a component in `src/components/Icon/icons` folder.
Use `IconChevron` as a reference. Basic concepts:

* Create new folder and name it `Icon[Name]`
* Place your code inside index.js
* Use https://jakearchibald.github.io/svgomg/ to optimize svg code
* Place svg beside js
* If icon have states (normal, hover, active), remove all `fill` attributes in svg and pass prop `hasState` to component

### Icons set

```
import IconChevron from './icons/IconChevron';

<div style={{ backgroundColor: 'darkgray' }}>
  <IconChevron />
  <IconChevron direction='bottom' />
</div>
```
