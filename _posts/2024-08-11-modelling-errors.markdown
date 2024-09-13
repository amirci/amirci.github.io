---
layout: post
title: To model or not to model errors, that is the question!
subtitle: Handle errors without hurting your code
date: 2024-08-12 00:34:00 -0700
categories: modeling
---

{: .box-warning}
When coding, handling errors is an inevitable challenge. We've all faced the question: What if this bit of code fails? But beyond just anticipating potential failures, how do we effectively communicate to others who might use our code that certain errors are expected? Moreover, what kinds of errors are possible?

## Introduction

To explore this, we will use a function as a representative example of a self-contained piece of code that can be called upon when needed.

A function is fundamentally defined by two main components: input and output.

* The input is a collection of arguments, each with its own set of restrictions or conditions. These are captured in a precondition, a predicate that outlines the requirements the input arguments must meet.

* The output is the result produced by the function when it’s called. This is described by the function's outcome and a postcondition, which is another predicate that specifies the conditions the result must satisfy in relation to the input arguments.

Understanding these components helps us better manage and communicate the potential for errors in our code, ensuring clarity and reliability for anyone who might interact with it.


### Errors for pure functions

Functions that abide to the definition explained in the previous paragraphs are called _pure functions_. That means that the function produces a result based on the input arguments and nothing more.

For example here is a very simple function that increments a number by one:

```python
def inc(n):
  """Increments the number by one"""

  return n + 1
```

The result of calling `inc` is based on the input argument. No matter how many times `inc` is called given the same _input_ the same _output_ will be obtained. It has a deterministic output.

Pure functions are quite easy to test, we just need to chose a specific input and test for the expected output. To test a function we need to review the precondition and postcondition:

* Precondition: any number.
* Postcondition: the input number plus one.

OK, sounds easy enough. Lets review possible scenarios for testing:

* The precondition is satisfied, the input is _indeed_ a number and the result should be the number incremented by one.
* The precondition is not satisfied, then we will get an error (somehow).
* An unexpected (unrelated) error can happen like running out of memory, or the CPU overheating or a zombie apocalypse. In that case we should get an error as well.

Wow! Even pure functions need to handle errors. Or perhaps not?

Lets review the scenarios to add tests. The first scenario may look like:

```python
def test_increment_when_n_is_a_number():
    assert increment(1) == 2
    assert increment(2) == 3
    assert increment(3) == 4
```

For the second scenario, in `Python` calling a function with the wrong _type_ will raise a `TypeError`:

```python
def test_increment_when_n_is_not_a_number():
    with pytest.raises(TypeError):
        increment("1")
    with pytest.raises(TypeError):
        increment(None)
```

Exceptions is a mechanism that `Python` (and many other languages) use to represent that an _exceptional_ error has happened. In order to "handle" the error we need to use a `try` and `exception` block. If not caught the exception will go up the stack of calls until it reaches the top, where there is a default _handler_ waiting.

But are we truly going to handle a `TypeError`? To do what with it? Probably nothing... we should let the exception bubble up and blow up at the top.

What about the third scenario? What should we do if there's no more memory? Or a zombie apocalypse?


```python
def test_increment_when_unrelated_happens():
   # not sure how to reproduce it
   # what should we do?
   ...
```

Again, probably nothing... bubble up it is.


For _pure functions_ there is no need to check for errors because the result will be always be related to the input arguments. Wait, what if I need to do validation or parse a string and it could fail? We will discuss modeling failures in the next sections. Let us first take a look what happens when functions are not _pure_.

### Side effects

Not all functions can be _pure_. Code needs to interact with the rest of the world. We need to call APIs, use files in the file system, use databases, random numbers, use the current date and many other similar scenarios.

When that happens it means the function call is going to have _side effects_. There is an impact on something beyond the input arguments. Perhaps the side effect is because we are using a database and some records will be modified. Or perhaps because we are doing a network call to an API.

Having _side effects_ brings another series of errors that we may or may not need to handle, but at least we should review what are the possible scenarios so we can decide how to write our tests.

For a database call, we may get errors related to network problems, or database issues like transactions, locking or concurrent updates. There is a very high chance that those errors will be exceptions. But what should we do with all the exceptions?

Can we just let them bubble up and be somebody else's problem? Definitely we can... not sure is the nicest convention to follow.

For example, we could have multiple function calls, function `A` calls function `B`, that calls function `C`, that calls function `D` that hits the database. Would function `A` want to receive a `TransactionError` that happens while calling function `D`?

Also, what if we want to retry? Maybe a `NetworkError` could be fixed by retrying when calling an API.

We need to care a tad more about the possible exceptions. That means our code now may look something like:

```python
try:
  the_database_call(arg1, arg2, ..., argN)
except TransactionError as te:
  # do something here
except NetworkError as ne:
  # do other stuff here
except Exception as e:
  # maybe we don't care?
```

In the section about _pure_ functions we hinted that when exceptions are _truly exceptional_ there is no point in handling them. They convey a terminal event has happened and a decision at the top level should be made in order to handle it.

But which exceptions are truly _exceptional_ and which are a _possible valid_ scenario that are worth being considered part of the contract (postcondition) for a function?


## Modeling expected failure

Lets imagine a function that divides two numbers:

```python
def divides(x, y):
  """
  Precondition: `x` and `y` are numbers. `y` must be number different than zero.
  Postcondition: returns the value of `x / y` or raises `ZeroDivisionError`
  """
  pass
```

Following the `python` convention, when the precondition is not met, the function will raise `ZeroDivisionError`.

This is a very well known case that most will be familiar with. Probably the code using `divides` will look like:

```python
def important_function(arg1, arg2, ...argN)
  """
  A very important function that uses `divides`
  """
  # ... important stuff here

  # We prefer not to use `try` and `exception` here to find out if the precondition will hold
  if argY > 0:
    result = divides(argX, argY)

  # ... more important stuff
```

Seems reasonable that the precondition is validated before calling the function. Having said that, a `try` block would work too but then we pay the price of the exception mechanism kicking in.

{: .box-note}
Other languages that enforce types
could offer a bit more safety by making a invalid scenario not possible and use a type to represent the valid values
of the domain that can be used. For example a `NonZeroNumber` type
to represent the _divisor_ could be defined. Still the problem now is shifted to how to construct a `NonZeroNumber`.

Lets look at a different case. A function that parses a string with a number and returns the number as a result:

```python
def parse_int(s: Str):
  """
  Precondition: A string with a characters that represent a number
  Postcondition: The actual number that matches the characters in the string or if not ERROR_PLACEHOLDER
  """
  pass
```

In this case, is not that cut and dry situation to decide if `ERROR_PLACEHOLDER` should be an exception of maybe
something else. We could use an exception, lets say `StringNotNumberError` (Python raises `ValueError` but I think this name is a bit more descriptive).

```python
def parse_int(s: Str):
  """
  Precondition: A string with a characters that represent a number
  Postcondition: The actual number that matches the characters in the string or if not raises a `StringNotNumberError`
  """
  pass
```

The caller, if they want to return _zero_ when the number cannot be parsed would do something like:

```python
def important_function():

    try:
        parsed = parse_int(s)
    except StringNotNumberError:
        parsed = 0

    # do something with `parsed`

```

Pretty standard so far. Perhaps there is an alternative that helps to make the code a bit more succinct, more expression like.

Instead of using an `Exception` we could change the contract of `parse_int` and return a value that represents that parsing could not be done:


```python
def parse_int(s):
  """
  Precondition: A string with a characters that represent a number
  Postcondition: The actual number that matches the characters in the string or if not returns `None`
  """
```

Now, using the function it is a bit more succinct:


```python
def important_function():

    parsed = parse_int(s) or 0

    # do something with `parsed`

```

That's better, pretty standard too. But `None` also represents when functions do not return a value and have _side effects_.
Let's take the idea a bit further into representing the absence of value with a type.
Instead of using `None` lets create a data type
that can help represent and convey that the result maybe has a value or maybe not. Using a different type will force
the caller to deal with the result and make sure it works as intended. A well known name for this type is `Maybe`.

```python
def parse_int(s) -> Maybe[Number]:
  """
  Precondition: A string with a characters that represent a number
  Postcondition: A `Maybe` instance that will have the actual number that matches the characters in the string
  or no value if is not possible to parse.
  """
```

This changes the caller function to handle the new data type (I'm using type hints for illustration purposes):


```python
def important_function():

    parsed = parse_int(s).get_or_else(0)

    # do something with `parsed`

```

Not bad! Now it is very clear that `parse_int` could fail (not an exceptional case though) and the caller has
to handle the result to make sure it works with the rest of the code.

This is fine and dandy for cases with clear semantics in terms of having a result or not at all. But that
will not work in cases where failures can come in many different flavors.


## Modeling failures with exceptions

There is no doubt that not handling exceptions is by far the easiest approach. However, you could argue that
documenting what kind of failures are possible in a postcondition is part of our responsibility as developers.

Exceptions are great when we need to skip many calls and bubble up the stack, but they are not meant as a mechanism
to communicate failure.

{: .box-note}
Languages like Java classify exceptions into checked and not checked exceptions. Checked exceptions have to be
declared in the signature of the function and the only way to get rid of it is either add it to the signature of
the caller function or use a `try` and `catch` block.

{: .box-success}
Kotlin in contrast, was designed also with exceptions but they are all _unchecked_. No need to add the exception
declaration in the signature of the function.

### Same exception different functions

What would happen if function `A` calls function `B` that can raise `ValidationError`, and also calls a function `C`
that also raises `ValidationError`. In this case both functions use the same library (not that far fetched).

The caller could try to catch the exception by doing something like:

```python
def function_a():

  try:
    function_b()
    function_c()
  except ValidationError as ve:
    # Which one raised the exception? B or C?
    # What should we do here?

```

The `except` block can not tell which function is the culprit. An alternative would be to split the exception block:


```python
def function_a():

  try:
    function_b()
  except ValidationError as ve:
    # Alright... should I set a flag to not call `function_c`?

  try:
    function_c()
  except ValidationError as ve:
    # Did something happen also with `function_b` ?
    # How can I handle both errors if they happen?
```

Adding an exception block it is a bit more verbose and involves custom logic to coordinate when to call or not the other functions.

### Same exception with nested functions

What if function `B` also calls function `C`? How can I differentiate which one raised the error? What does it mean for function `A` if function `C` raises an error two nested calls down the stack?

```
  function_a ->
    function_b ->
      function_c raises `ValidationError`
```

The function `A` has a contract with function `B`... but why should `A` know about function `C` failures? That breaks the _abstraction_ contract between functions and couples `A` to `C`.

{: .box-note}
A function creates a contract with a caller by specifying the precondition and postcondition. Inputs and outputs.
The function _abstracts_ the caller from the implementation details. If the caller needs to know how the _callee_
is implemented, then the abstraction is broken and probably the contract is broken as well.

### Status code vs exceptions

Let's explore a function that calls an API using HTTP. This example is a very common scenario. The contract when calling
includes a result data structure with a _status code_ field that identifies what kind of response was obtained.
The `200` range means a valid response,
`301` means redirect, `400` means the parameters have some kind of issue and the infamous `404` means not found and so on.


```python
def calling_an_api(request):
  """
  Precondition: Takes a valid request
  Postcondition: Returns a response with a status code that represents the HTTP status code
  """
  pass
```

Having a response with a `status_code` field is OK but depending of the status code some other fields in the response
may be important and useful. This is a hint that using multiple types to represent the response could be a good idea. We can use exceptions to model the different kind of errors and the information
associated with each of them.

```python
class UnauthorizedError(HttpException):
  """ Represents a 401 status code """
  pass

class InvalidParametersError(HttpException):
  """ Represents a 400 status code """
  pass

class UnknownError(HttpException):
  """ Represents a 500 status code """
  pass


class Timeout(?????): # Not sure what the base class should be
  """ Represents timeout calling, not sure what's the base class """
  pass

```

And then of course, the caller needs to catch all these exceptions. Lots of `try` blocks ...

## Modeling failures with types

Modeling errors is a lot of work but makes transparent when a function can "fail". The caller is responsible
to handle the _failure_ and decide what to do. Perhaps some of the _failures_ should not bubble up, or can be converted
to failures that actually have meaning to the caller.

Using pure functions whenever possible may mitigate the effort of modeling errors but that is hardly a viable solution.

We discussed briefly how to use the `Maybe` type to represent the absence of value. This idea is quite
useful but does not help much when a _failure_ needs to be conveyed. To model a scenario where the failure
information can be passed as part of the result we are going to use a well known abstraction called `Either`.

The `Either` type has two possible values, a `Right` value as in the _right_ thing to do and a `Left` value
(commonly used to hold the value for failure or error).

{: .box-note}
Many languages already have this concept as part of the core language. `Go` returns a _tuple_ where the second
component is the error. `Rust` has a `Result` type to represent possible failures. `Swift` also
has a `Result` type.

The result of a function that calls an API could be modeled with the `Either` type to contain both scenarios:

```python
def call_an_api(request_info) -> Either[PossibleFailures, Response]:
  """
  Precondition: makes a network request to the API passing the `request_info`
  Postcondition: Returns a `Right(Response)` when the call succeeded or a `Left(PossibleFailures)`
  with the detail of the different possible failures
  """
```

Where the definition of `PossibleFailures` could be an `enum` or multiple data classes.

Using `Either` conveys very clearly to the caller that failures are not only expected but also are part of
the contract of the function and should be handled accordingly.

### Combining multiple failures

Modeling errors with the `Either` type has an extra benefit baked in that can simplify our code.

As much as we may like having function definitions with complete transparency in terms of failures
the crux of modeling errors is to deal with them as callers.

Similar to modeling errors with exceptions (let's ignore for a second the extra cost of using exceptions) adding
code to handle every possible error becomes tedious and adds the feeling of fighting _fire_ with _fire_.

To illustrate this point, let's use a function that validates parameters, calls an API and then makes a database operation.

```python
def api_handler(request_info) -> ApiHttpResponse:
  """
  Handles the request of the API XXX by calling the API YYY and then inserting results in the database
  Precondition: The request is valid
  Postcondition: Calls API YYY with the information from the request and uses the result to store it
  in the database. The failures are handled as follows:
    - An invalid `request_info` because is missing a field returns a `InvalidRequestError`.
    - An invalid `request_info` because of having a date older than 2001, `DateTooOldInRequestError`.
    - Failure in the API call returns 'TryAgainLaterServiceUnavailableError'.
    - Failure in storing the results of the API returns `ContactAdministratorError`.
    - Any other error returns `UnknownError`.
  """

  try:
    validate_request(request_info)
  exception MissingFieldError as me:
    # respond with `InvalidRequestError`
    ...
  exception DatToOldError as dto:
    ...

  # Similarly add two more `try` blocks and decide on which exception

```

In his [blog](https://fsharpforfunandprofit.com/rop/) Scott talks about "Railway Oriented Programming". That is a
technique that helps identifying _failures_ early in the flow and skip other calls gracefully.

We could use a similar idea. Instead of using `Exception` to communicate the possible failures, each function will
return an `Either`:

```python
def validate_request(request_info: PotentialRequest) -> Either[ValidationError, InternalApiRequest]:
  """
  Precondition: A request info that may have incomplete fields or invalid value for date
  Postcondition: A `Right[InternalApiRequest]` or a `Left[ValidationError]` where
  a `ValidationError` can be one of `DateTooOldError` or `MissingFieldError`
  """
  pass


def call_internal_api(request: InternalApiRequest) -> Either[CallApiError, InformationToStore]:
  """
  Precondition: A request with all the necesary information to make the call
  Postcondition: A `Right[InformationToStore]` or a `Left[CallApiError]` where
  a `CallApiError` can be one of `NetworkError`, `TimeoutError`, `InvalidParametersError`...
  """
  pass


def store_to_database(info: InformationToStore) -> Either[UpdateDbError, TotalRecordsUpdated]:
  """
  Precondition: A valid information to be stored in the database
  Postcondition: A `Right[TotalRecordsUpdated]` or .... (you get the gist)
  """
```

Now we could do something like:

```python
def api_handler(request_info) -> ApiHttpResponse:

    first_result = validate_request(request_info)

    if first_result.is_left():
      # more code here

    # do the same for each call
```

But we are missing on of the cool features of `Either`, using `.then` to chain multiple calls:

```python
def api_handler(request_info) -> ApiHttpResponse:

    return validate_request(request_info)
      # When the result is `Right` calls the next function, if `Left` skips the call
      .then(call_internal_api)
      # When the result is `Right` calls the next function, if `Left` skips the call
      .then(store_to_database)
      # Call `to_success_response` if is `Right` otherwise call `to_failure_response`
      .either(to_success_response, to_failure_response)

```


## What should I do then?

Whether through using exceptions, status codes, or more sophisticated types like `Either`, the goal is to ensure that errors are conveyed clearly so they can be handled in a way that is predictable and easy to implement and maintain.

Each error modeling approach has its own context where it shines:

* Exceptions are best suited for scenarios where you need to handle unexpected, exceptional situations that are meant to bubble up through multiple layers of the stack. Using an exception to communicate a possible error is more "expensive" and if not caught breaks the contract between functions. The caller may find exceptions that are born nested in multiple levels of function calls, without the ability of act on them.

* Returning special values (like None or a custom error value) is useful when you want to keep your function calls simple and direct, especially in situations where failure can take only one shape and there is no need to convey more than that. This method is simpler to implement and easier to understand but as the code grows it will become insufficient to model all kinds of failures and the code will become harder to read and maintain.

* Using types like `Maybe` or `Either` is a great choice when you want to enforce handling of possible failures directly in your code’s logic. These types make it clear that a function can either succeed or fail, and they compel the caller to deal with both scenarios. This approach makes your code resilient, predictable, testable and easy to maintain.

Incorporating these practices into your codebase not only improves the robustness of your applications but also fosters a more reliable and understandable system for those who come after you. By thoughtfully modeling failures, you create a safety net that allows your code to fail gracefully, making it easier to debug, test, and ultimately, trust. As we continue to build more complex systems, the principles discussed here serve as a foundation for writing resilient and clear code that stands the test of time.

