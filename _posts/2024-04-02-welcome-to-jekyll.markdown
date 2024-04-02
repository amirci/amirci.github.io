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

```ts
import { pipe } from 'fp-ts/function';
import * as A from 'fp-ts/Array';

const changeExistingStudentsTable = (
  tableInfo: any,
  columnChanges: any,
  idx: number,
) => {
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

First bit I noticed (before reading the body of the function) is that the _signature_ uses `any` for the arguments.

Perhaps we could _narrow_ the types to make it more specific to the actual possible values. Plus one for modeling with types!

Looking a bit how the arguments are used, it looks like we could have a `Student` that can have any _properties_ and then a `StudentTable` that contains the columns and a collection of values (rows).

```ts
type Student = Record<string, any>;

type ColumnName = string;

type StudentTable {
  columns: ColumnName[];
  values: readonly Student[];
}

```

The changes can also be captured in a type, like:

```ts
type ColumnChange = {
  deleted: string | undefined;
  original: string;
  current: string;
  mergedCol: string;
};

type UpdateFn = (tables: StudentTable[], idx: number) => StudentTable[];

type ChangeMapFn = (change: ColumnChange) => UpdateFn;
```

## Implementing the changes

```ts
const applyChangesToTable = (tableInfo: TableInfo[], changes: readonly ColumnChange[], idx: number) => {
  return pipe(
    changes,
    ROA.filter(isChange),
    ROA.map(changeToUpdateFn),
    ROA.reduce(tableInfo, (table: TableInfo[], updateFn: UpdateFn) => updateFn(table, idx))
  );
};

```

