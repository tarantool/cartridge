export const getAnimationPromise = (animation, timeout) =>
  new Promise((resolve, reject) => {
    let animationResult;
    try {
      animationResult = animation();
    } catch (error) {
      reject(error);
    }

    const resolveWithTimeout = () => resolve(animationResult);
    timeout ? setTimeout(resolveWithTimeout, timeout) : resolveWithTimeout();
  });

export class AnimationFlow {
  constructor(animation, timeout) {
    this.animationPromise = getAnimationPromise(animation, timeout);
  }

  then(animation, timeout) {
    this.animationPromise = this.animationPromise.then(() => getAnimationPromise(animation, timeout));
    return this;
  }

  catch(errorHandler) {
    this.animationPromise = this.animationPromise.catch(errorHandler);
    return this;
  }
}

export const animate = (...args) => new AnimationFlow(...args);
