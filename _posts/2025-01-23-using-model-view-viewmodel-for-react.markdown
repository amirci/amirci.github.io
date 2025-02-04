---
layout: post
title: "State management evolution (part II)&#58; Using MVVM"
subtitle: A tongue twister that will blow your mind
tags: [react view-model state]
mermaid: true
credit-img: Photo by https://unsplash.com/photos/brown-chillax-board-B6na4YFIecI
cover-img: assets/img/chillax.jpg
thumbnail-img: assets/img/chillax_tn.jpg
---


{: .box-intro }
The MVVM (Model-View-ViewModel) design pattern can make the code easier to maintain and reduce the coupling between the component and the implementation of state management.

## Introduction

In [Part I]() of the series we explored using a _reducer_ to manage state in a web application. To bring you up to speed, we started discussing an example that requires multiple states to manage the logic of the _React_ component and after a few iterations we evolved into a `useReducer` hook that helps capture explicitly the events that modify the state.

The example was about a student form that needed information:


```jsx

const initialState = {
  student: {
    studentId: 0,
    firstName: '',
    lastName: '',
  },
  errors: [],
  canSubmit: false,
  isLoading: false,
};

const studentReducer = (oldState, action) => {
  switch (action.type) {
    case 'student_changed':
      return changeStudentEvent(action.fieldName, action.value, oldState);
    case 'fetching_id_started':
      return fetchingIdStartedEvent(oldState);
    case 'fetching_id_finished':
      return fetchingIdFinishedEvent(action.newId, oldState);
  }
  throw Error('Action type invalid:' + action.type)
};

const StudentForm = (reducerFn = studentReducer) => {
  // State to store student data
  const [state, dispatch] = useReducer(reducerFn, initialState);

  ....
}

```

### What's the problem?

Do not get me wrong, working with a `useReducer` hook can work fine, but I think there are a few things that can be improved.

What we like:

* Logic is captured separate from the view, reducing the coupling.
* The state can be immutable.
* Is simpler to test the reducer and view separate but we should:
  * Instead of hardcoding the reducer to the view we can pass it as an argument.
  * Then we can truly test separately view and reducer.


What we would like to improve:

* Avoid having other hooks besides the MVVM.
* Try to simplify update notification by using less boilerplate than creating and raising events.
* Have a clear separation between the _model_ we need as part of the domain and what we need just for the view to work.


## In a nutshell

In the MVVM pattern, the _ViewModel_ serves as the intermediary between the _Model_ (business/data layer) and the _View_ (UI). It encapsulates all business logic, ensuring that the view remains free from complex calculations and state transitions. By centralizing logic in the ViewModel, developers can isolate and manage business rules in a cohesive and organized manner.


One of the _MVVM’s_ strengths is its ability to expose only the necessary data and actions to the _View_. The _ViewModel_ acts as a tailored API for the _View_, presenting data in a format that’s easy to consume (e.g., formatted strings or precomputed values). This reduces boilerplate in the UI and ensures a clear contract between the View and ViewModel.

Going back to the _Tiny counter_ example the _Model_ is just a counter:

```js
const Counter = {
  value: 0
}
```

Now the `VM` needs to represent everything that the _View_ needs. First we need a _value_ to represent the _counter_ but also we need to have a way to indicate the counter should be increased.

```js
const CounterViewModel = {
   value,
   increment,
   decrement
}
```

And the `VM` can be passed as an argument to the _component_:


```jsx
import React, { useState } from 'react';

const Counter = (vm) => {
  const [count, increment] = vm(0);

  return (
    <div>
      <p>You clicked {count} times</p>
      <button onClick={increment}>
        Click me
      </button>
    </div>
  );
}
```

The _ViewModel_ is _exactly_ what the component needs and the relationship is one to one making the relationship between them simpler.

Inside the _ViewModel_ we are free to use a _reducer_ hook or any other technology piece we see fit. However the implementation will stay hidden.

The testing is straightforward because we understand at a glimpse the responsibilities of the _View_ and _ViewModel_ and how the should interact.

## Back to the student form

The next section tackles modifying the student form to switch from a `useReducer` hook to a view model. All the code can be found [here](https://stackblitz.com/edit/vitejs-vite-gtr44uvm).

To build a _ViewModel_ that provides only what the view needs we need to create an object that has:

* Student information to display in the fields
* Know if the student ID is still loading
* Know if there are errors to display (that means we cannot submit the form)
* Handle the change of the value of the fields
* Handle the form submission

In terms of a view model _hook_ I imagine a constructor that returns three values:

```jsx
const StudentForm = ({viewModel = StudentFormViewModel}) => {
  // State to store student data
  const [state, handleForm, handleField] = viewModel()

  if (state.isLoading) {
    return <h3>Fetching ID... please wait</h3>;
  }

  return ( .... )
}

```

Please note that we have moved already a good portion of the logic out of the view to the _ViewModel_ making the view smaller:


```jsx
  // Not needed, part of the VM
  const handleChange = (e) => {...};

  // Not needed, part of the VM
  useEffect(() => { ... }, []);

  // Not needed, part of the VM
  const handleSubmit = (e) => { ... };
```

The `state` has not changed, here is a refresher:


```js
const initialState = {
  student: {
    studentId: 0,
    firstName: '',
    lastName: '',
  },
  errors: [],
  canSubmit: false,
  isLoading: false,
};

```

The view logic has no changes, still uses the handlers to notify changes and get updates:

```jsx
const StudentForm = ({viewModel = StudentFormViewModel}) => {
  // State to store student data
  const [state, handleField, handleForm] = viewModel()

  if (state.isLoading) {
    return <h3>Fetching ID... please wait</h3>;
  }

  return (
    <form onSubmit={handleForm}>
      <div>
        <label>Student ID:</label>
        <input
          type="text"
          name='studentId'
          value={state.student?.studentId}
          onChange={handleField('studentId')}
          readOnly={true}
        />
      </div>
      <div>
        <label>First Name:</label>
        <input
          type="text"
          name="firstName"
          value={state.student?.firstName}
          onChange={handleField('firstName')}
        />
      </div>

      // rest of the form
      ...

    </form>
  );
};

```

The implementation of the view model is not an important, feel free to take a look at the code.


### Binding the values

Another aspect of using a _ViewModel_ is the opportunity to _bind_ the parts of the view model to the view.

That means that the view model takes _advantage_ of his tailored nature and uses this knowledge to simplify further the view declaration.

By looking at the code above is evident that each field in the form needs to have a counterpart in the view model, that means that there will be some repetition on each `input` field:

```jsx
    <form onSubmit={handleForm}>
      <div>
        <label>Student ID:</label>
        <input
          type="text"
          name='studentId'                    // repeat for every field
          value={state.student?.studentId}    // repeat ...
          onChange={handleField('studentId')} // repeat ...
          readOnly={true}
        />
      </div>
      <div>
        <label>First Name:</label>
        <input
          type="text"
          name="firstName"                    // same here... repeat...
          value={state.student?.firstName}
          onChange={handleField('firstName')}
        />
      </div>
      ...
  </form>
```

Using some kind of binding will help us reduce boilerplate. A simple way of doing it could be to replace each handler in the view model with a function that will return the attributes needed for each field:

```jsx

const StudentForm = ({viewModel = StudentFormViewModel}) => {
  const [state, bindInput, bindForm] = viewModel()
  ...
}

```

The function `bindInput` will be used for fields and `bindForm` for the whole form:

```js
  <form {... bindForm()}>
      <div>
        <label>Student ID:</label>
        <input type="text" {... bindInput('studentId')} readOnly={true}/>
      </div>
      <div>
        <label>First Name:</label>
        <input type="text" {... bindInput('firstName')}/>
      </div>
      ...
  </form>

```

The _binding_ functions can connect the handlers inside the view model:

```jsx
  const bindInput = (name) => ({
    name,
    value: state.student[name],
    onChange: handleChange
  });

  const bindForm = () => ({ onSubmit: handleSubmit });

```

The binding helps to remove repetitive code and make the view easier to follow:

```jsx
    <form {... bindForm()}>
      <div>
        <label>Student ID:</label>
        <input type="text" {... bindInput('studentId')} readOnly={true}/>
      </div>
      <div>
        <label>First Name:</label>
        <input type="text" {... bindInput('firstName')}/>
      </div>

      <div>
        <label>Last Name:</label>
        <input type="text" {... bindInput('lastName')}/>
      </div>

      ...
   </form>

```

## Looks cool, but how do I choose?

Both MVVM and `useReducer` are effective patterns for managing state and business logic, but they cater to different needs:

- **MVVM** excels in larger applications where a clear separation of concerns, testability, and preprocessed view-specific data are priorities. The ViewModel’s ability to centralize business logic and present a clean API to the View ensures scalability and maintainability.

- **useReducer** shines in React-based projects that require lightweight, functional state management. Its simplicity and compatibility with React’s declarative paradigm make it a natural choice for medium-complexity applications.

When choosing between these approaches, consider the scale of your application, the complexity of your business logic, and your testing requirements. For robust, scalable solutions, MVVM is often the better choice. For simpler, React-native implementations, `useReducer` might be all you need.

