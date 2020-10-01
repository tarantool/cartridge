import './styles.css';

if (!document.getElementById('PageRequestIndicator-indicator')) {
  const element = document.createElement('div')
  element.id = 'PageRequestIndicator-indicator'
  element.className = 'pageRequestIndicator-indicator'
  const child = document.createElement('div')
  child.className = 'pageRequestIndicator-progress'
  element.appendChild(child)
  document.body.appendChild(element)
}
const indicatorEl = document.querySelector('#PageRequestIndicator-indicator');
const progressEl = document.querySelector('#PageRequestIndicator-indicator > *');

const setDisplay = display => indicatorEl.style.display = display;
const setWidth = width => progressEl.style.width = `${width}%`;
const setOpacity = opacity => progressEl.style.opacity = opacity;
const setDanger = () => progressEl.style.backgroundColor = 'red';
const resetDanger = () => progressEl.style.backgroundColor = '';

function initPageRequestIndicator(props = {}) {
  const {
    colorTransition = 200,
    opacityTransition = 600,
    firstStepPercentage = 15,
    firstStepTransition = 300,
    nextStepPercentage = 20,
    nextStepTransition = 200,
    pendingStepPercentage = 2.7,
    pendingStepTransition = 200,
    pendingStepFrequency = 500,
    successStepTransition = 400,
    successStepTimeout = 500
  } = props;

  const setTransitions = (stepTransition = pendingStepTransition) => progressEl.style.transition
    = `background-color ${colorTransition}ms, opacity ${opacityTransition}ms, width ${stepTransition}ms`;

  const resetTransitions = () => progressEl.style.transition = '';

  let width = 0, activeAnimation = null;

  const getNextWidth = percentage => (100 - width) * percentage / 100 + width;

  const pending = () => {
    setWidth(width = getNextWidth(pendingStepPercentage));
  };

  const reset = () => {
    setDisplay('none');
    resetTransitions();
    resetDanger();
    setWidth(width = 0);
    setOpacity('1');
  };

  const prepare = () => {
    setDisplay('block');
    setTransitions();
  };

  function createAnimation() {
    class Animation {
      constructor() {
        this.active = true;
        this.timerId = null;
        this.queue = [];

        const runOnActive = method =>
          (...args) => this.runOnActive(() => method.call(this, ...args));

        this.run = runOnActive(this.run);
        this.next = runOnActive(this.next);
        this.success = runOnActive(this.success);
        this.pushStep = runOnActive(this.pushStep);
        this.nextStep = runOnActive(this.nextStep);
        this.setStep = runOnActive(this.setStep);
        this.setTimeout = runOnActive(this.setTimeout);
        this.setInterval = runOnActive(this.setInterval);
      }

      runOnActive(action) {
        this.active && action();
        return this;
      }

      run() {
        this
          .setTimeout(reset)
          .setTimeout(prepare)
          .setTimeout(
            () => (setTransitions(firstStepTransition), setWidth(width = firstStepPercentage)),
            pendingStepFrequency
          )
          .setTimeout(() => setTransitions(pendingStepTransition))
          .setInterval(pending, pendingStepFrequency);
      }

      next() {
        this.dropQueue()
          .setTimeout(
            () => (setTransitions(nextStepTransition), setWidth(width = getNextWidth(nextStepPercentage))),
            pendingStepTransition
          )
          .setInterval(pending, pendingStepFrequency);
      }

      end(error) {
        this.dropQueue()
          .setTimeout(
            () => (error && setDanger(), setTransitions(successStepTransition), setWidth(width = 100)),
            successStepTimeout
          )
          .setTimeout(() => setOpacity('0'), opacityTransition)
          .setTimeout(reset)
          .setTimeout(prepare)
          .setTimeout(() => this.active = false);
      }

      success() {
        this.end();
      }

      error() {
        this.end(true);
      }

      stop() {
        this.dropCurrentStep();
        this.active = false;
      }

      pushStep(step) {
        this.queue.push(step);
        if (this.queue.length === 1) {
          step.action();
        } else if (this.queue.length === 2 && this.queue[0].interval) {
          this.dropCurrentStep();
          step.action();
        }
      }

      nextStep() {
        this.dropCurrentStep();
        const step = this.queue[0];
        if (step) {
          if (step.interval && this.queue.length > 1 && this.queue[1].interval) {
            this.nextStep();
          } else {
            step.action();
          }
        }
      }

      dropCurrentStep() {
        this.timerId = null;
        this.queue.shift();
        return this;
      }

      dropQueue() {
        this.timerId = null;
        this.queue = [];
        return this;
      }

      setTimeout(cb, timeout = 0) {
        const action = () => {
          cb();
          const timerId = setTimeout(() => this.timerId === timerId && this.nextStep(), timeout);
          this.timerId = timerId;
        };
        this.pushStep({ action, interval: false });
      }

      setInterval(cb, timeout) {
        const action = () => {
          cb();
          const timerId = setInterval(() => this.timerId === timerId ? cb() : clearInterval(timerId), timeout);
          this.timerId = timerId;
        };
        this.pushStep({ action, interval: true });
      }
    }

    return new Animation();
  }

  return {
    run: () => {
      if (activeAnimation && activeAnimation.active) {
        activeAnimation.stop();
      }
      return activeAnimation = createAnimation().run();
    }
  };
}

export const pageRequestIndicator = initPageRequestIndicator();
