---
layout: post
title:  "Refactoring multiple updates with reduce"
date:   2024-04-02 00:16:58 -0700
categories: refactoring
---

## Introduction

The refactoring story today is about a UI editor for a table of _Students_ that lets a user
add, rename and remove columns.

The result of an operation is a series of changes that have to be applied and saved to the database.

I will skip the _React_ portion of the code and focus on how to model the changes with types and simplify the update process.

NOTE: The code uses [fp-ts](https://gcanti.github.io/fp-ts/) types and functions. You can see the functions or namespaces imported at the top.

```ts
import { pipe } from 'fp-ts/function';
import * as A from 'fp-ts/Array';

const changeExistingStudentsTable = (tableInfo: any, columnChanges: any, idx: number) => {
  const isChange = (columnChange: any): boolean =>
    !(
      !columnChange.mergedCol &&
      !columnChange.deleted &&
      columnChange.original === columnChange.current
    );

  const mergeCol = (sourceCol: string, targetCol: string, needDeleteSourceCol: boolean) => (d: any) => {
      // if create new col and merge at the same time,
      // no need to remove the new col as it does not exist; only fill merged col with null
      if (!needDeleteSourceCol) {
        d[idx].values = d[idx].values.map(v => {
          v[targetCol] = null;
          return v;
        });
      } else {
        d[idx].columns = A.filter(e => e !== sourceCol)(d[idx].columns);
        d[idx].values = d[idx].values.map(v => {
          v[targetCol] = v[sourceCol];
          v[sourceCol] = undefined;
          return v;
        });
      }
      return d;
    };

  const deleteCol = (deletedCol: string, isExist: boolean) => (d: any) => {
    // if {current : 'new column', deleted: true} -> add and immediately delete, no need to delete
    // if {current : 'new column', original: 'exist name', deleted: true}  -> add 'new column' save, then change name and delete --> delete 'new column'
    if (isExist) {
      // todo:
      d[idx].columns = A.filter(e => e !== deletedCol)(d[idx].columns);
      d[idx].values = d[idx].values.map(v => {
        v[deletedCol] = undefined;
        return v;
      });
    }
    return d;
  };

  const addCol = (newCol: string) => (d: any) => {
    d[idx].columns.push(newCol);
    d[idx].values = d[idx].values.map(v => {
      // todo: how to refactor
      v[newCol] = undefined;
      return v;
    });
    return d;
  };

  const renameCol = (old_name: string, new_name: string) => (d: any) => {
    d[idx].columns = pipe(
      d[idx].columns,
      A.filter(e => e !== old_name),
      cols => [...cols, new_name],
    );
    d[idx].values = d[idx].values.map(v => {
      v[new_name] = v[old_name];
      return v;
    });
    return d;
  };

  const getChangeFunc = (columnChange: any): any => {
    if (columnChange.mergedCol) {
      return mergeCol(
        columnChange.current,
        columnChange.mergedCol,
        Boolean(columnChange.original),
      );
    } else if (columnChange.deleted) {
      return deleteCol(columnChange.original, Boolean(columnChange.original));
    } else if (!columnChange.original) {
      return addCol(columnChange.current);
    } else if (columnChange.original !== columnChange.current) {
      return renameCol(columnChange.original, columnChange.current);
    }
  };
  const modifyData = (cur: any, op: any) => op(cur);
  return pipe(
    columnChanges,
    A.filter(isChange),
    A.map(getChangeFunc),
    A.reduce(tableInfo, modifyData),
  );
};

```

## Identifying candidates for refactoring

I noticed that the _signature_  of `changeExistingStudentsTable` uses the type `any` for each of the arguments.

Perhaps I could _narrow_ the types to make it more specific to the actual possible values. Plus one for modeling with types!

Looking at how the arguments are used in the main function, seems like a good idea to create a `Student` type
and a `StudentTable` type that contains the _columns_ and a collection of _values_ (rows).


```ts
type Student = Record<string, any>;

type ColumnName = string;

type StudentTable {
  columns: ColumnName[];
  values: readonly Student[];
}

// For example a table that has First Name, Last Name, Age and Eye Color would look like:

const table: StudentTable = {
  columns: ["FirstName", "LastName", "Age", "EyeColor"],
  values: [
    {FirstName: "Juan", LastName: "Rodriguez", Age: 10, EyeColor: "Green"},
    {FirstName: "Rose", LastName: "Bidai", Age: 11, EyeColor: "Brown"}
  ]
}

```

### Modeling changes to the columns

The changes could be modeled as a type (I call it _legacy_ to mark the difference later with the refactored version):

```ts
type LegacyColumnChange = {
  deleted?: string;
  original?: string;
  current?: string;
  mergedCol?: string;
};
```

Having all fields optional hints that some combinations probably are invalid. We can try to represent the changes in
a way that captures the original intention behind the fields but makes the states that are invalid not possible.


```ts
type ColumnName = string;
type RemoveColumn = { type: 'remove'; target: ColumnName };
type AddColumn = { type: 'add'; target: ColumnName };
type RenameColumn = { type: 'rename'; newName: ColumnName; oldName: ColumnName };

// Possible values for the type of change
type ValidColumnChange = RemoveColumn | AddColumn | RenameColumn;

// But sometimes a change should be ignored
type NoChange = { type: 'none' };

// The actual type combines both
type ColumnChange = ValidColumnChange | NoChange;
```

Good first step, however, the original code relies on the _logic_ behind the combination of the fields.

For example the column `current` and `deleted` may both be set to indicated that the column
was added but deleted after.

Instead of _encoding_ the business logic of the change in the combination of fields it would be better
to make the logic explicit by using the types defined
[above](#however-having-all-fields-optional-hints-that-some-combinations)
and have clear data that represents each change.

Here is the explanation of what the fields represent in `LegacyColumnChange`
(columns names A and B are just for example purposes):

| Fields | Change | Implementation |
|-----------|---------|----------------|
| `mergedCol` and `original `exists | Merge B into A| Delete A and rename B to A |
| `mergedCol` exists but `original` not| No change needed | - |
| `deleted` and `original` exists | Delete B | Column B should be removed from `columns` and from each object in `values` |
| `original` does not exist but `current` exists | Add B | Column B added dot `columns` (no need to modify values) |
| `original` and `current` do not exist | No change needed | - |
| `original` different than `current` | Rename column A with B | Column A should be called B in `columns` |
| any other case | No change needed | - |

Because when merging columns represent actually two operations, using a function 
that given a _legacy_ change generates multiple `ColumnChange` captures all scenarios.

```ts
// Converts a legacy change to a well defined change
function legacyToChange(change: LegacyColumnChange): readonly ColumnChange[] {
  // skip this for now
  // the logic will be the one mentioned in the table above.
}
```

## Converting a change into a function that applies it to the table

Let's take a look at the signature of the functions that take a column change 
and return another function that will actually apply the change to the `StudentTable`.


```ts
const mergeCol = (sourceCol: string, ...) => (d: any) => ...;

const deleteCol = (deletedCol: string, ...) => (d: any) => ...;

const addCol = (newCol: string) => (d: any) => ...;

const renameCol = (oldName: string, ...) => (d: any) => ...;
```

All the function are [higher order functions](https://en.wikipedia.org/wiki/Higher-order_function).

Higher order functions is a cool technique that helps us encapsulate logic that can be called later.

Each function matching a change will return in turn another function that captures how to apply the change.

Similar to before, is better to have types for the arguments and the result:

```ts
// Takes the tables and the index, does the change, and returns the tables updated
type UpdateFn = (tables: StudentTable[], idx: number) => StudentTable[];

// T can be any change
// Given an `AddColumn` I need an `UpdateFn` that adds the column
// Given a `RemoveColumn` I need an `UpdateFn` that removes the column
// and so on ...
type ChangeMapFn<T extends ColumnChange> = (change: T) => UpdateFn;
```

But the function will be called only for changes that are valid, thus I can use the `ValidColumnChange` type instead.

Every opportunity to narrow the domain of a type is a chance to improve the code for reading.


```ts
type ChangeMapFn<T extends ValidColumnChange> = (change: T) => UpdateFn;
```

For example now the `AddColumn` function looks like:

```ts
// T in this case is `AddColumn`
const addCol = ({ target: ColumnName }: AddColumn) => {
  return (tables: readonly StudentTable[], idx: number) => {
     // the logic goes here
  }
};
```

I could simplify a bit by using the `ChangeMapFn` type:

```ts
// The types are specified on the left
const addCol: ChangeMapFn<AddColumn> = ({ target }) => (tables, idx) => ....

```

Before looking at each function I want to rework how the decision of what to call is made.

## Deciding which function to call

Here is the original code:

```ts
// Decides given a change which function will do the actual update
const getChangeFunc = (columnChange: LegacyColumnChange): any => {
  if (columnChange.mergedCol) {
    return mergeCol(...),
    );
  } else if (columnChange.deleted) {
    return deleteCol(...));
  } else if (!columnChange.original) {
    return addCol(...);
  } else if (columnChange.original !== columnChange.current) {
    return renameCol(...);
  }
};
```

Because I have a function that captures the logic of converting legacy into `ColumnChange` I'll change 
the signature of the function (also rename it to `changeToUpdateFn`):

```ts
const changeToUpdateFn = (change: ValidColumChange): UpdateFn => ...
```

One option, is to take advantage that the `ColumnChange` type has a `type` discriminator field, and write
a `switch` to obtain the function that will actually do the update:


```ts
switch (change.type) {
  case 'add':
    return addCol(change); // returns a function of type UpdateFn
  case 'remove':
    return deleteCol(change); // same here
  case 'rename':
    return renameCol(change); // same here
}
```

However, considering that `addCol`, `deleteCol`, etc, all return the same _kind_ of function perhaps there is
a way to avoid repeating the last `return` at the end of each branch.

This looks quite like pattern matching on the type. And though TS does not support it (yet) there are libraries
that can be used like [ts-pattern](https://github.com/gvergnaud/ts-pattern):

```ts
// Takes a valid column change ... and uses the `type` field to decide
const changeToUpdateFn = (change: ValidColumnChange): UpdateFn =>
  match(change)
    .with({ type: 'add' }, (change: AddColumn) => addCol(change))
    .with({ type: 'rename' }, ...)
    .with({ type: 'remove' }, ...)
    .exhaustive();
```

This is a case when using a _lambda_ to call a function is equivalent to use the function itself.
Here is the code with the all the functions:

```ts
const changeToUpdateFn = (change: ValidColumnChange): UpdateFn =>
  match(change)
    .with({ type: 'add' }, addCol) // when matching calls a function with the `change`
    .with({ type: 'rename' }, renameCol)
    .with({ type: 'remove' }, deleteCol)
    .exhaustive();

```

## The update functions

The signature for all the functions is very similar (they all return an `UpdateFn`):


```ts
// A function to convert a change into an updating function
type ChangeMapFn<T extends ValidColumnChange> = (change: T) => UpdateFn;

const deleteCol: ChangeMapFn<RemoveColumn> = (change) => (table, idx) => ...
const renameCol: ChangeMapFn<RenameColumn> = (change) => (table, idx) => ...
const addCol: ChangeMapFn<AddColumn> = (change) => (table, idx) => ...
```

Also all functions have in common that they modify the `columns` and the `values` for the `StudentTable`.

To capture that common functionality I could create a function that focuses on the updates:

```ts
type ColumnNames = readonly ColumnName[];
type Values = readonly Record<ColumnName, unknown>[];

// The function takes two functions as arguments
// One to update `ColumnNames`
// One to update `Values` (optional, by defeault is the _identity_ function)
const updateTables =
  (colFn: (columns: ColumnNames) => ColumnNames, valsFn: (vals: Values) => Values = (v) => v) =>
  (tables: StudentTable[], idx: number) => {
    const table = tables[idx];
    table.columns = colFn(table.columns);
    table.values = valsFn(table.values);
    return tables;
  };

```

### Deleting columns

Let's see how it would look to use `updateTables` with `deleteCol`. 

Two functions are needed, one to update the columns and one to update the values:

#### A function that updates the columns

To update the columns collection the function needs to take the columns and return a new collection 
without the _target_ column name.

I will use `filter` from the `ReadOnlyArray` module in [fp-ts](https://gcanti.github.io/fp-ts/modules/ReadonlyArray.ts.html#filter) to _remove_ the _target_ column returning a collection without it.

```ts
import * as ROA from 'fp-ts/ReadonlyArray';
const removeColumnName = (target: ColumnName) => ROA.filter<ColumnName>((e) => e !== target);
```

#### A function that updates the values

To update the values collection the function needs to go over each value object and remove the field
that is associated to the _target_ column.

I will use `map` to go over each value and `omit` to remove the field from the object:

```ts
import * as STR from 'fp-ts-std/Struct'; // fp-ts-std library

const removeColumnValue = (target: ColumnName) => ROA.map(STR.omit([target]));
```

With both functions created, now I can change the declaration for `deleteCol` to:

```ts
const deleteCol: ChangeMapFn<RemoveColumn> = ({ target }) =>
  updateTables(removeColumnName(target), removeColumnValue(target));
```

### Adding and renaming columns

Similarly we can use `updateTables` for both `addCol` and `renameCol`:

```ts
const renameColumnValues = (oldName: string, newName: string) => ROA.map(STR.renameKey(oldName)(newName));

// flow composes functions from right to left
// returning a function/lambda that takes a collection and returns
// a collection is the same as composing filter + append
const renameColumName = (oldName: ColumnName, newName: ColumnName) =>
  flow(
    ROA.filter<ColumnName>((e) => e !== oldName),
    ROA.append(newName)
  );

const renameCol: ChangeMapFn<RenameColumn> = ({ newName, oldName }) =>
  updateTables(renameColumName(oldName, newName), renameColumnValues(oldName, newName));

const addCol: ChangeMapFn<AddColumn> = ({ target }) => updateTables(ROA.append(target));

```

And voila! Now the functions are more descriptive and much easier to read and understand.

## Putting it all together

The last bit is to combine all the functions created so far.

Here is the original code, I moved the functions outside the scope of the function body for clarity:

```ts
const changeExistingStudentsTable = (tableInfo: StudentsTable[], changes: readonly ColumnChange[], idx: number) => {
  const modifyData = (cur: any, op: any) => op(cur);

  // This `pipe` takes the changes, filters the ones that are actually a change
  // creates a function and then applies it to the table.
  return pipe(
    columnChanges,
    A.map(legacyToChange), // I added this
    A.filter(isChange),
    A.map(getChangeFunc),
    A.reduce(tableInfo, modifyData),
  );
};
```

I like the general idea of `changeExistingStudentsTable` (except the name, I'll change that later). There is a collection of changes that need to be _applied_ to a `StudentTable` to
obtain a new `StudentTable`.

That idea pretty much looks like a `reduce` because the changes are _folded_ into a an existing _table_ to create
a new version.

The steps are:
* Convert legacy change into a `ColumnChange`.
* Filter changes that are `none`.
* For every change create a function that will apply the change to a table.
* Take the collections of functions to apply and fold them into the table creating an updated table.

I feel the code is succinct and to the point, I'll leave it as it is for now.

### Filtering not valid changes

To filter the valid changes I need a _predicate_ that returns _true_ when the type of the change
is not `none`. Something like:

```ts
function isValidChange(change: ColumnChange): Boolean ....
```

However, using a plain predicate won't suffice:

```ts
pipe(
  ...
  ROA.filter(isValidChange), // returns a collection of ColumnChange
  ROA.map(changeToUpdateFn), // changeToUpdateFn takes a ValidColumChange not a ColumnChange
  ...
)
```

To fix it, I would like to use a TS
[type guard](https://www.typescriptlang.org/docs/handbook/advanced-types.html) to help returning the matching type:

```ts
function isValidChange(change: ColumnChange): change is ValidColumnChange {
  return change.type != 'none';
}
```

### The big enchilada

Putting all together, renaming the function to be a bit more descriptive and using the previous
refactored functions:


```ts
const applyChangesToTable = (tables: StudentTable[], changes: readonly ColumnChange[], idx: number) => {
  return pipe(
    changes,
    ROA.flatMap(legacyToChange), // One legacy to many changes, thus I need to _flatten_
    ROA.filter(isValidChange),   // Thanks to the type predicate, all the changes ar ValidColumChange
    ROA.map(changeToUpdateFn),   // Convert each change into a function to do the update
    ROA.reduce(tables, (acc: StudentTable[], updateFn: UpdateFn) => updateFn(table, idx)) // apply each update
  );
};

```


## Summary

No good refactoring should happen without answering the question "Is this better than before?".

The code is definitely larger than the original. The amount of lines is more than double.

We [started](#the-refactoring-story-today-is-about-a-ui-editor-for-a-table-of) from lots of declarations with `any` and worked our way out to:

* Use types to describe the concepts in the domain: This is a huge benefit when reading the code.
* Make invalid combinations impossible: The type predicate will return only valid changes.
* Use small functions with clear goals: Simpler to read and follow.
* Avoid encoding logic into the changes: Each change now is separate and is only data.
* Created helper functions to capture common functionality: Is similar to having a DSL (domain specific language)

For all these reasons I think the code is better than before and the refactoring is worth it.

Here is all the code together:

```ts
type Student = Record<string, unknown>;
type ColumnName = string;
type ColumnNames = readonly ColumnName[];
type Values = readonly Student[];

type StudentsTable = {
  columns: ColumnNames;
  values: Values;
};

// Possible changes
type RemoveColumn = { type: 'remove'; target: ColumnName };
type AddColumn = { type: 'add'; target: ColumnName };
type RenameColumn = { type: 'rename'; newName: ColumnName; oldName: ColumnName };

type ValidColumnChange = RemoveColumn | AddColumn | RenameColumn;

// We should consider a change that does nothing
type NoChange = { type: 'none' };
type ColumnChange = ValidColumnChange | NoChange;

// A function to update one of the tables by index
type UpdateFn = (tables: StudentsTable[], idx: number) => StudentsTable[];

// A function to convert a change into an updating function
type ChangeMapFn<T extends ValidColumnChange> = (change: T) => UpdateFn;

// Helper function to create an updating function for columns and values
const updateTables =
  (colFn: (columns: ColumnNames) => ColumnNames, valsFn: (vals: Values) => Values = (v) => v) =>
  (tables: StudentsTable[], idx: number) => {
    const table = tables[idx];
    table.columns = colFn(table.columns);
    table.values = valsFn(table.values);
    return tables;
  };

// Helper function that removes a column name from the list of columns
const removeColumnName = (target: ColumnName) => ROA.filter((e) => e !== target);

// Helper function that removes a column value from the list of values
const removeColumnValue = (target: ColumnName) => ROA.map(STR.omit([target]));

// Helper function that renames the column in the list of values
const renameColumnValues = (oldName: string, newName: string) => ROA.map(STR.renameKey(oldName)(newName));

// Helper function that renames a column name
const renameColumName = (oldName: ColumnName, newName: ColumnName) =>
  flow(
    ROA.filter<ColumnName>((e) => e !== oldName),
    ROA.append(newName)
  );

// The actual function that will apply the RemoveColumn change
const deleteCol: ChangeMapFn<RemoveColumn> = ({ target }) =>
  updateTables(removeColumnName(target), removeColumnValue(target));

// The actual function that will apply the RenameColumn change
const renameCol: ChangeMapFn<RenameColumn> = ({ newName, oldName }) =>
  updateTables(renameColumName(oldName, newName), renameColumnValues(oldName, newName));

// The actual function that will apply the AddColumn change
const addCol: ChangeMapFn<AddColumn> = ({ target }) => updateTables(ROA.append(target));

// Converts a change into an updating function
const changeToUpdateFn = (change: ValidColumnChange): UpdateFn =>
  match(change)
    .with({ type: 'add' }, addCol)
    .with({ type: 'rename' }, renameCol)
    .with({ type: 'remove' }, deleteCol)
    .exhaustive();

// Type predicate to check if a change is valid
function isValidChange(change: ColumnChange): change is ValidColumnChange {
  return change.type != 'none';
}

// constructors for change types
const createDeleteColumn = (target: ColumnName): RemoveColumn => ({ type: 'remove', target });

const createAddColumn = (target: ColumnName): AddColumn => ({ type: 'add', target });

const createRenameColumn = (newName: ColumnName, oldName: ColumnName): RenameColumn => ({ type: 'rename', newName, oldName });

const noChange = { type: 'none' };

// Converts a legacy change to a well defined change
function legacyToChange(change: LegacyColumnChange): readonly ColumnChange[] {
  const noChanges = [noChange];
  if (mergedCol && original) {
    return [createDeleteColumn(mergedCol), createRenameColumn(mergedCol, current!)];
  }

  if (deleted && original) {
    return [createDeleteColumn(original)];
  }
  if (!original && current) {
    return [createAddColumn(current)];
  }
  if (original != current) {
    return [createRenameColumn(current!, original!)];
  }

  return noChanges;
}

// The main function that applies the changes to the table
export const applyChangesToTable = (tables: StudentsTable[], changes: readonly ColumnChange[], idx: number) => {
  return pipe(
    changes,
    ROA.flatMap(legacyToChange),
    ROA.filter(isValidChange),
    ROA.map(changeToUpdateFn),
    ROA.reduce(tables, (table: StudentsTable[], fn: UpdateFn) => fn(table, idx))
  );
};

```

### Afterthoughts

A good practice after refactoring is to review the code looking for parts
that could be written better. I have a couple of thoughts.

#### Why use a collection of `StudentTable` and a index?

It seems that the code works with one table at a time, perhaps instead of working with
a collection only one `StudentTable` could be used and the main function could return the table updated.


```ts
type UpdateFn = (table: StudentTable) => StudentTable;

export const applyChangesToTable = (table: StudentsTable, changes: readonly ColumnChange[]) => {
  return pipe(
    changes,
    ...
    ROA.reduce(table, (table: StudentsTable[], fn: UpdateFn) => fn(table))
  );
};

```

#### Filtering changes may not be necessary

When converting `LegacyColumnChange` into a collection of `ColumnChange` instead of returning
`NoChange` the function could return an empty collection instead. Because all the results will
be concatenated at the end an empty collection will not affect the result.

```ts
function legacyToChange(change: LegacyColumnChange): readonly ValidColumnChange[] {
   // the logic here dos not change

  return [];
}

// That means that there's no need to filter


export const applyChangesToTable = (tables: StudentsTable[], changes: readonly ColumnChange[], idx: number) => {
  return pipe(
    changes,
    ROA.flatMap(legacyToChange), // no need to filter after
    ROA.map(changeToUpdateFn),
    ...
  );
};
```

## Resources

If you wish to play with the code I have created a public [repl.it](https://replit.com/@amirci/2024-04-02-Refactor-using-reduce?v=1) that can be forked.

Do you have questions or comments? Feel free to drop me a line.

Enjoy!

