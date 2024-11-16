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

### Last but not least

Sometimes is not the last argument that we would need to fix to a value, how can we use `curry` in that case?

From the docs:

> Secondly, the special placeholder value `R.__` may be used to specify "gaps", allowing partial application of any combination of arguments, regardless of their positions. If `g` is as above and `_` is `R.__`, the following are equivalent:

```js
g(1, 2, 3)
g(_, 2, 3)(1)
g(_, _, 3)(1)(2)
g(_, _, 3)(1, 2)
g(_, 2)(1)(3)
g(_, 2)(1, 3)
g(_, 2)(_, 3)(1)
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

All three functions coincide on two things: the last argument and the return value.

What if, instead of passing a type with information that has to be decoded into __which function to call_ we would have a way to pass directly the _actual_ action to call?

First, let us use `curry` in some of the event functions:

```js
const changeStudentEvent = R.curry((fieldName, value, oldState) => .... )

const fetchingIdStartedEvent = ... // same as before

const fetchingIdFinishedEvent = R.curry((newId, oldState) => .... )
```

Using the new definitions we could update the reducer function as follows:


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

Good idea! However, we are still using an _event_ that needs to be translated into a function. We could do something better:

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

Here is an idea, we could change `validateStudent` to be able to configure how long each field on the `Student` should be? Something like this:


```js
// Returns a new state with errors if any
const validateStudent = (config, state) => ...;
```

That would break the composition, because is not a unary function any longer.

Fear not loyal reader! You have `curry` <s>powder</s> _power_ in your tool-belt now!

First let us change `validateStudent` to be _curried_:


```js
// Returns a new state with errors if any
const validateStudent = R.curry((config, state) => ...);
```

Now we can easily change the call to obtain a _unary_ function instead:


```js
const changeStudentEvent = R.curry(
  R.pipe(
    updateStudent,
    validateStudent({firstName: {minLength: 10}, lastName: {minLength: 20}}),
    updateSubmit
  )
);
```

## Any leftovers?

Of course! A cornucopia remember?

Both `pipe` and `compose` return a function, but why create a function first and then pass the argument?

Once again, `Ramda` comes to your aid! The [flow](https://ramdajs.com/docs/#flow) function takes one argument and a collection of functions. From the documentation:

> `flow` helps to avoid introducing an extra function with named arguments for computing the result of a function pipeline which depends on given initial values. Rather than defining a referential transparent function `f = (_x, _y) => R.pipe(g(_x), h(_y), …)` which is only later needed once `z = f(x, y)`, the introduction of `f`, `_x` and `_y` can be avoided: `z = flow(x, [g, h(y),…]`

And here is the example:

```js
R.flow(9, [Math.sqrt, R.negate, R.inc]); //=> -2

const personObj = { first: 'Jane', last: 'Doe' };
const fullName = R.flow(personObj, [R.values, R.join(' ')]); //=> "Jane Doe"
const givenName = R.flow('    ', [R.trim, R.when(R.isEmpty, R.always(fullName))]); //=> "Jane Doe"
```

### Something for the road

Looking at the other functions in the code from [last blog post]({{ page.previous.url }}) we can see that all the functions that update the _state_ need to follow the requirements from the `React` _reducer hook_. The _state_ cannot be modified. That means that _updating_ the state has to be done by _copying_ the previous _state_ and overwriting the new values.

That is _kind_ of easy in _Javascript_ by using the `...` notation (spread syntax) for arrays and objects.

To copy the previous state and update the `errors` field as an empty array we could do something like:

```js
const newState = { ...oldState, errors: [] }

```

The code reads fine when is small and the property is not nested. Here is an update a bit more involved:

```js
const updateStudent = (fieldName, newValue, state) => {
  return { ...state, student: { ...state.student, [fieldName]: newValue } };
};

```

Luckily `Ramda` provides two functions to add elements to an object and return a copy, the first one is [`assoc`](https://ramdajs.com/docs/#assoc):

> Makes a shallow clone of an object, setting or overriding the specified property with the given value. Note that this copies and flattens prototype properties onto the new object as well. All non-primitive properties are copied by reference.

```js
R.assoc('c', 3, {a: 1, b: 2}); //=> {a: 1, b: 2, c: 3}
```

And the second one is [`assocPath`](https://ramdajs.com/docs/#assocPath):

> Makes a shallow clone of an object, setting or overriding the nodes required to create the given path, and placing the specific value at the tail end of that path. Note that this copies and flattens prototype properties onto the new object as well. All non-primitive properties are copied by reference.

```js
R.assocPath(['a', 'b', 'c'], 42, {a: {b: {c: 0}}}); //=> {a: {b: {c: 42}}}

// Any missing or non-object keys in path will be overridden
R.assocPath(['a', 'b', 'c'], 42, {a: 5}); //=> {a: {b: {c: 42}}}
```

This simplifies nested updates, it is more declarative and helps with copying the values.

Here is the same `updateStudent` using `assocPath`:

```js
const updateStudent = (fieldName, newValue, state) =>
  R.assocPath(['student', fieldName], newValue, state);

```

## Please give us some stars on your way out!

Small utility functions are a developer's Swiss army knife. Quite a few of them like `map`, `reduce`, `filter`, `zip`, `compose`, `pipe`, etc, are so well known that there is a very big chance they will appear in a programming language.

Getting familiar with such functions help to convey intent when writing code and may give you an advantage when working with a new language.


