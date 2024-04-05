---
layout: post
title:  "Refactoring multiple updates with reduce"
date:   2024-04-02 00:16:58 -0700
categories: refactoring
---

## The problem

The refactoring story today is about a UI editor for a table of _Students_ that lets a user
add, rename and remove columns.

To do so it generates a series of changes than have to be applied and saved to the database.

We will skip the _React_ portion of the code and we will focus on how to model the changes and the update process.

NOTE: The code uses [fp-ts]() types and functions. You can see the functions or namespaces imported at the top.

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

I noticed first (before reading the body of the function) that the _signature_ uses the type `any` for each of the arguments.

Perhaps we could _narrow_ the types to make it more specific to the actual possible values. Plus one for modeling with types!

Looking at how the arguments are used in the main function, it looks like we could create a `Student` type that can have _properties_ and then a `StudentTable` that contains the columns and a collection of values (rows).


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

The changes could also be captured in a type, something like:

```ts
type ColumnChange = {
  deleted?: string;
  original?: string;
  current?: string;
  mergedCol?: string;
};
```

However, having all fields optional hints that some combinations are probably are invalid. We can try to represent the changes in
a way that captures the intention behind each change and makes the states that cannot be valid impossible to build.


```ts

type ColumnName = string;
type RemoveColumn = { type: 'remove'; target: ColumnName };
type AddColumn = { type: 'add'; target: ColumnName };
type RenameColumn = { type: 'rename'; newName: ColumnName; oldName: ColumnName };

// Possible values for the type of change
type ValidColumnChange = RemoveColumn | AddColumn | RenameColumn;

// But sometimes we have change that should be ignored
type NoChange = { type: 'none' };

// The actual type combines both
type ColumnChange = ValidColumnChange | NoChange;

```

### The body of the function

Here is a simplified version of the code to highlight the structure of the body.
I removed the body of the functions declared at the top and added some comments to clarify.

I am also using the types I defined above and moved the function declarations outside.

```ts
const isChange = (columnChange: any): boolean => ...

const mergeCol = (sourceCol: string, targetCol: string, needDeleteSourceCol: boolean) => (d: any) => ...;

const deleteCol = (deletedCol: string, isExist: boolean) => (d: any) => ...;

const addCol = (newCol: string) => (d: any) => ...;

const renameCol = (oldName: string, newName: string) => (d: any) => ...;

// This function returns, given a change, another function that will apply the change to the
// selected students table
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

const changeExistingStudentsTable = (tableInfo: StudentsTable[], changes: readonly ColumnChange[], idx: number) => {
  const modifyData = (cur: any, op: any) => op(cur);

  // This `pipe` takes the changes, filters the ones that are actually a change
  // creates a function and then applies it to the table.
  return pipe(
    columnChanges,
    A.filter(isChange),
    A.map(getChangeFunc),
    A.reduce(tableInfo, modifyData),
  );
};
```

I like the general idea. There is a collection of changes and we need to _apply_ them to a `StudentTable` to
obtain a new `StudentTable`.

That idea pretty much looks like a `reduce` because we are _folding_ all the changes into a an existing _table_ to create
a new version.

The steps are:
* Filter changes that are `none`.
* For every change create a function that will apply the change to a table.
* Take the collections of functions to apply and fold them into the table creating an updated table.

I feel the code is succinct and to the point, I'll leave it as it is for now.

## Converting a change definition into an actual function

To decide what the change should do the code has one function for each _kind_ of change:

```ts
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
```

First of all we have a new type to represent the change. The type helps to capture some of the logic that was coded before
by identified each _kind_ of change.

The new function signature will look something like this:

```ts
const getChangeFunc = (change: ColumChange): ??? => ...
```

We can add some types to represent the functions that will do the change:

```ts
type UpdateFn = (tables: StudentTable[], idx: number) => StudentTable[];

type ChangeMapFn = (change: ColumnChange) => UpdateFn;
```

But we are going to call the function only for changes that are valid, so we can use the `ValidColumnChange` type instead.

Every opportunity to narrow the domain of a type is a chance to improve the code for reading.

Now the signature changed to:


```ts
const getChangeFunc = (change: ValidColumChange): UpdateFn => ...
```

We could take advantage that the `ColumnChange` type has a `type` discriminator field, and write something
like this to obtain the function that will actually do the update:


```ts
  switch (change.type) {
    case 'add':
      return addCol(change);
    case 'remove':
      return deleteCol(change);
    case 'rename':
      return renameCol(change);
  }
```

However, considering that `addCol`, `deleteCol`, etc, all return the same _kind_ of function perhaps there's
a way to avoid a bit of repetition. 

Luckily we can use [ts-pattern](https://github.com/gvergnaud/ts-pattern) for that:

```ts
const changeToUpdateFn = (change: ValidColumnChange): UpdateFn =>
  match(change)
    .with({ type: 'add' }, addCol) // when matching calls a function with the `change`
    .with({ type: 'rename' }, renameCol)
    .with({ type: 'remove' }, deleteCol)
    .exhaustive();

```

The last bit is to have a function that helps us filter the valid changes. We can use a TS 
[type guard](https://www.typescriptlang.org/docs/handbook/advanced-types.html) that helps with the conversion:

```ts
function isValidChange(change: ColumnChange): change is ValidColumnChange {
  return change.type != 'none';
}
```

Putting all together (and renaming the function to be a bit more descriptive) we get:

```ts
const applyChangesToTable = (tableInfo: TableInfo[], changes: readonly ColumnChange[], idx: number) => {
  return pipe(
    changes,
    ROA.filter(isValidChange),
    ROA.map(changeToUpdateFn),
    ROA.reduce(tableInfo, (table: TableInfo[], updateFn: UpdateFn) => updateFn(table, idx))
  );
};

```

## The update functions

For each possible `ValidColumChange` the code in `changeToUpdateFn` returns an `UpdateFn`:


```ts
type UpdateFn = (tables: StudentTable[], idx: number) => StudentTable[];

```

The function that decides how to apply the change will return a new `UpdateFn` in each
case that will be applied later in the _reduce_.


```ts
type ChangeMapFn<T extends ValidColumnChange> = (change: T) => UpdateFn;
```

The signature for each function is very similar:


```ts
const deleteCol: ChangeMapFn<RemoveColumn> = (change) => (table, idx) => ...
const renameCol: ChangeMapFn<RenameColumn> = (change) => (table, idx) => ...
const addCol: ChangeMapFn<AddColumn> = (change) => (table, idx) => ...
```

Also all functions have in common that they modify the `columns` and the `values` for the `StudentTable`.

We could create a function that can capture that common bit of work:

```ts
type ColumnNames = readonly ColumnName[];
type Values = readonly Record<ColumnName, unknown>[];

const updateTables =
  (colFn: (columns: ColumnNames) => ColumnNames, valsFn: (vals: Values) => Values = (v) => v) =>
  (tables: TableInfo[], idx: number) => {
    const table = tables[idx];
    table.columns = colFn(table.columns);
    table.values = valsFn(table.values);
    return tables;
  };

```

### Deleting columns

Using `updateTables` the `deleteCol` function now looks like:

```ts
import * as ROA from 'fp-ts/ReadonlyArray';
import * as STR from 'fp-ts-std/Struct'; // fp-ts-std library

const removeColumnValue = (target: ColumnName) => ROA.map(STR.omit([target]));

const renameColumnValues = (oldName: string, newName: string) => ROA.map(STR.renameKey(oldName)(newName));

const deleteCol: ChangeMapFn<RemoveColumn> = ({ target }) =>
  updateTables(removeColumnName(target), removeColumnValue(target));

```
