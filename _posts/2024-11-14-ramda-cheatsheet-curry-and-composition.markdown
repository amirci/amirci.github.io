---
layout: post
title: "Ramda cheat sheet - Curry and friends"
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

Though those languages may not be considered _functional languages_ many of the techniques used in _functional languages_ can be really useful. These abstractions and patterns have been around for many years and have been honed and perfected for developers to use.

Such a technique is _currying_.

## Cute food picture, but what is it?

At the heart of the "programming with functions" tool-belt lies the well known technique of wrapping a function in another function. That means using a function that takes a function as a parameter and returns a new function that behaves like the old one but with added functionality.

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


## That doesn't sound real world

I hear you. Let us use an example for a `React` reducer hook with a reducer function. This is the example from [last blog post]({{page.previous.url}}):

```js
const studentReducer = (oldState, action) => {
  switch (action.type) {
    case 'student_changed':
      return changeStudentEvent(action.fieldName, action.value, oldState);
    case 'fetching_id_started':
      return fetchingIdStartedEvent(oldState);
    case 'fetching_id_finished':
      return fetchingIdFinishedEvent(action.newId, oldState);
  }
  throw Error('Invalid action: ' + action.type);
};
```

Each action _type_ matches with calling a function as follows:

* `"student_changed"` calls `changeStudentEvent`
* `"fetching_id_started"` calls `fetchingIdStartedEvent`
* `"fetching_id_finished"` calls `fetchingIdFinishedEvent`

Also, let us note that all three functions coincide on two things: the last argument and the return value.

What if instead of passing a type with information that has to be decoded into which function to call we would have a way to pass directly the _actual_ action to call?

First, let us use `curry` for each of the event functions:

```js
const changeStudentEvent = R.curry((fieldName, value, oldState) => .... )

const fetchingIdStartedEvent = ... // same as before

const fetchingIdFinishedEvent = R.curry((newId, oldState) => .... )
```

Using the new definitions let us update the reducer function:


```js
const studentReducer = (oldState, action) => {
  targetFn = null;

  switch (action.type) {
    case 'student_changed':
      targetFn = changeStudentEvent(action.fieldName, action.value);
    case 'fetching_id_started':
      targetFn = fetchingIdStartedEvent;
    case 'fetching_id_finished':
      targetFn = fetchingIdFinishedEvent(action.newId);
  }

  if(targetFn) {
    return targetFn(oldState);
  }

  throw Error('Invalid action: ' + action.type);
};
```

Good idea, but we are still using an _event_ that needs to be translated into a function. We could do something better:

```js
const studentReducer = (oldState, actionFn) => {
  return actionFn(oldState);
};
```

And change the calls to the `dispatch` functions to take advantage of the curried functions, the whole code can be found [here](https://stackblitz.com/edit/vitejs-vite-hp9p47?file=src%2FStudentForm.jsx):

```jsx
const StudentForm = (reducerFn = studentReducer) => {
  // State to store student data
  const [state, dispatch] = useReducer(reducerFn, initialState);

  // Handle form input change
  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;
    dispatch(changeStudentEvent(name, type === 'checkbox' ? checked : value));
  };

  useEffect(() => {
    const finishLoading = (newId) => {
      dispatch(fetchingIdFinishedEvent(newId));
    };
    dispatch(fetchingIdStartedEvent);
    setTimeout(finishLoading, 800, 123456);
  }, []);

  // .... the rest of the code
}

```

There is no need for an event type and there is no need to validate the event, because each event is the actual function that needs to be called.

## What's for dessert?

Another scenario where `curry` can shine is where several functions are combined in a sequence of calls. That is commonly known as function composition.

From the `Ramda` website we have the definition for [`compose`](https://ramdajs.com/docs/#compose):

> Performs right-to-left function composition. The last argument may have any arity; the remaining arguments must be unary.

```js
const classyGreeting = (firstName, lastName) => "The name's " + lastName + ", " + firstName + " " + lastName
const yellGreeting = R.compose(R.toUpper, classyGreeting);
yellGreeting('James', 'Bond'); //=> "THE NAME'S BOND, JAMES BOND"

R.compose(Math.abs, R.add(1), R.multiply(2))(-4) //=> 7
```

{: .box-warning }
Languages like [`Haskell`](https://learnyouahaskell.com/higher-order-functions) have an infix function `.` (yes, it is a dot) to compose functions. That helps quite a bit with nested parenthesis and is similar to what we learn in school or university.

An alternative function is [`pipe`](https://ramdajs.com/docs/#pipe):

> Performs left-to-right function composition. The first argument may have any arity; the remaining arguments must be unary.

```js
const f = R.pipe(Math.pow, R.negate, R.inc);

f(3, 4); // -(3^4) + 1
```

{: .box-warning }
Languages like [F#](https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/functions/#pipelines) have a _pipe operator_ (\|>). In [Clojure](https://clojure.org/) there is a [thread last](https://clojure.org/guides/threading_macros) macro that helps writing sequences of functions that take the result of the previous one. Even there is a proposal for [JS](https://github.com/tc39/proposal-pipeline-operator) to include a pipeline operator.


### Show me the money

Using the same example we used before from the [last post]({{page.previous.url}}) we could improve some of the functions that do the validation:

```js
// Returns a new state with errors if any
const validateStudent = (state) => ...;

// Returns a new state with the student field updated to the new value
const updateStudent = (fieldName, newValue, state) => ...;

// Returns a new state with the submit flag updated
const updateSubmit = (state) => ...;

// Applies validation, update student and update submit
const changeStudentEvent = R.curry((fieldName, newValue, oldState) => {
  return updateSubmit(
    validateStudent(
      updateStudent(fieldName, newValue, oldState)
    )
  );
});
```

The last function combines the other three functions, let us review the signature of each function to see if they are a good fit for _composition_ (I'm using `State` as the type for the _state_):

* `updateStudent` takes `(fieldName, newValue, oldState)` and returns a new `State`
* `validateStudent` takes `oldState` and returns a new `State`
* `updateSubmit` takes `oldState` and returns a new `State`

From the `Ramda` documentation we know that:

> The last argument may have any arity; the remaining arguments must be unary.

Perfect match! Let us update the function! Remember the first function goes last:

```js
const changeStudentEvent = R.curry((fieldName, newValue, oldState) => {
  const composed = R.compose(updateSubmit, validateStudent, updateStudent);
  return composed(fieldName, newValue, oldState);
});
```

I used an intermediate variable to create the function for illustration purposes. It is the same sequence as before and if you are somehow familiar with composition the sequence of calls is more explicit.

Having said that, we could also use `pipe` that does not need to reverse the order and matches how we describe the sequence of actions:


```js
const changeStudentEvent = R.curry((fieldName, newValue, oldState) => {
  const piped = R.pipe(updateStudent, validateStudent, updateSubmit);
  return piped(fieldName, newValue, oldState);
});
```

{: .box-warning }
Functions that call another function with the same arguments can be simplified. When a function `f` calls `g` with the same arguments then `f == g` and can be replaced. For example `const f = (x) => g(x)` is equivalent to `const f = g`.

That means that we could simplify the function further:


```js
const changeStudentEvent = R.curry(R.pipe(updateStudent, validateStudent, updateSubmit));
```

What if we would like to change `validateStudent` to be able to configure how long each field should be? Something like this:

```js

// Returns a new state with errors if any
const validateStudent = (config, state) => ...;
```

That would break the composition, because is not a unary function any longer.

Fear not loyal reader! You have `curry` <s>powder</s> _power_ in your tool-belt now!
