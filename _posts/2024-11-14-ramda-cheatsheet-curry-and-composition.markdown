---
layout: post
title: "Ramda cheatsheet - Curry and composition"
subtitle: Spicy, aromatic and very reusable
tags: [ramda, curry, composition, functional-programming]
mermaid: true
credit-img: Photo by xxx
cover-img: assets/img/curry-with-code.jpg
---


{: .box-intro }
The Ramda library is a cornucopia of utility functions. Curry is an extremely useful (and spicy) function that helps to fix  arguments creating new functions quickly.

## Introduction

Working with a language that supports high order functions (functions that can take as arguments functions or return functions as a result) make functions a very valuable tool in our arsenal.

Functions can be passed to configure filters, lambdas can be created to define getters, functions can be passed tailor behavior for testing, functions can be returned to hide complex logic and much much more.

We are talking about languages like Kotlin, Rust, Python, Javascript, Ruby and many others. That is a lot of power in your hands.

Though those languages may not be considered _Functional languages_ many of the techniques used in _functional languages_ can be really useful. These abstractions and patterns have been around for many years and have been honed and perfected for developers to use.

Such a technique is _currying_.

## Cute food picture, but what is it?

At the heart of the "programming with functions" tool-belt is wrapping a function in another function. That means using a function that takes a function as a parameter and returns a new function that behaves like the old one but with added functionality.

That's a mouthful! Let us see it in action:

```js
const plus = (x, y) => x + y

// we have a function that uses the other function
const addTwo = (y) => plus(2, y)

assert(4, addTwo(2));
assert(8, addTwo(6));

```

Have you ever looked at a function and thought:

> Wow, that is almost what I need, if only I had the same function with one less parameter

Exactly! [Ramda's curry](https://ramdajs.com/docs/#curry) it is the function for you!

From the docs:

> Returns a curried equivalent of the provided function. The curried function has two unusual capabilities. First, its arguments needn't be provided one at a time. If f is a ternary function and g is R.curry(f), the following are equivalent:

```js
g(1)(2)(3)
g(1)(2, 3)
g(1, 2)(3)
g(1, 2, 3)
```

Using it in the previous example would be something like this:

```js
import * as R from 'ramda';

// Now `plus` is curried!
const plus = R.curry((x, y) => x + y)

// With just one argument returns another function that takes one parameter
const addTwo = plus(2)

assert(4, addTwo(2));
assert(8, addTwo(6));
```




