{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Some variants of the generic treap.                                     *
*                                                                           *
*   Copyright(c) 2019 A.Koverdyaev(avk)                                     *
*                                                                           *
*   This code is free software; you can redistribute it and/or modify it    *
*   under the terms of the Apache License, Version 2.0;                     *
*   You may obtain a copy of the License at                                 *
*     http://www.apache.org/licenses/LICENSE-2.0.                           *
*                                                                           *
*  Unless required by applicable law or agreed to in writing, software      *
*  distributed under the License is distributed on an "AS IS" BASIS,        *
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. *
*  See the License for the specific language governing permissions and      *
*  limitations under the License.                                           *
*                                                                           *
*****************************************************************************}
unit LGTreap;

{$MODE OBJFPC}{$H+}
{$INLINE ON}
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH NESTEDPROCVARS}

interface

uses
  SysUtils, Math,
  LGUtils,
  {%H-}LGHelpers,
  LGStrConst;

type
  { TGBstUtil - binary search tree utility, it assumes TNode is a record type;
      TNode must provide:
        field/property/function Key: TKey;
        field/property/function Left: ^TNode;
        field/property/function Right: ^TNode;
      functor TCmpRel (comparision relation) must provide:
        function Compare([const[ref]] L, R: TKey): SizeInt; }
  generic TGBstUtil<TKey, TNode, TCmpRel> = class
  public
  type
    PNode      = ^TNode;
    TOnVisit   = procedure(aNode: PNode; var aGoOn: Boolean) of object;
    TNestVisit = procedure(aNode: PNode; var aGoOn: Boolean) is nested;

    class function  GetTreeSize(aNode: PNode): SizeInt; static;
    class function  GetHeight(aNode: PNode): SizeInt; static;
    class function  GetLowest(aRoot: PNode): PNode; static;
    class function  GetHighest(aRoot: PNode): PNode; static;
    class function  FindKey(aRoot: PNode; constref aKey: TKey): PNode; static;
    class function  GetLess(aRoot: PNode; constref aKey: TKey): PNode; static;
    class function  GetLessOrEqual(aRoot: PNode; constref aKey: TKey): PNode;static;
    class function  GetGreater(aRoot: PNode; constref aKey: TKey): PNode; static;
    class function  GetGreaterOrEqual(aRoot: PNode; constref aKey: TKey): PNode; static;
    class procedure ClearTree(aNode: PNode); static;
    class procedure FreeNode(aNode: PNode); static; inline;
    class function  PreOrderTraversal(aRoot: PNode; aOnVisit: TOnVisit): SizeInt; static;
    class function  PreOrderTraversal(aRoot: PNode; aOnVisit: TNestVisit): SizeInt; static;
    class function  InOrderTraversal(aRoot: PNode; aOnVisit: TOnVisit): SizeInt; static;
    class function  InOrderTraversal(aRoot: PNode; aOnVisit: TNestVisit): SizeInt; static;
    class function  PostOrderTraversal(aRoot: PNode; aOnVisit: TOnVisit): SizeInt; static;
    class function  PostOrderTraversal(aRoot: PNode; aOnVisit: TNestVisit): SizeInt; static;
  end;

  { TGIndexedBstUtil assumes TNode has also a field/property/function Size: SizeInt,
    which is the size of its subtree }
  generic TGIndexedBstUtil<TKey, TNode, TCmpRel> = class(specialize TGBstUtil<TKey, TNode, TCmpRel>)
  public
    class function GetNodeSize(aNode: PNode): SizeInt; static; inline;
    class function GetByIndex(aRoot: PNode; aIndex: SizeInt): PNode; static;
    class function GetKeyIndex(aRoot: PNode; constref aKey: TKey): SizeInt;
  end;

  { TGLiteTreap implements randomized Cartesian BST(only);
    on assignment and when passed by value, the whole treap is copied;
      functor TCmpRel (comparision relation) must provide:
        function Compare([const[ref]] L, R: TKey): SizeInt; }
  generic TGLiteTreap<TKey, TValue, TCmpRel> = record
  public
  type
    PNode = ^TNode;
    TNode = record
    private
      FLeft,
      FRight: PNode;
      FKey: TKey;
      FPrio: SizeUInt;
    public
      Value: TValue;
      property Left: PNode read FLeft;
      property Right: PNode read FRight;
      property Key: TKey read FKey;
    end;

    TUtil       = specialize TGBstUtil<TKey, TNode, TCmpRel>;
    TOnVisit    = TUtil.TOnVisit;
    TNestVisit  = TUtil.TNestVisit;
    TEntry      = specialize TGMapEntry<TKey, TValue>;
    TEntryArray = array of TEntry;

  private
    FRoot: PNode;
    function  GetCount: SizeInt;
    function  GetHeight: SizeInt;
    class function  NewNode(constref aKey: TKey): PNode; static;
    class function  CopyTree(aRoot: PNode): PNode; static;
  { splits tree of aRoot into two subtrees, where min(R.Key) >= aKey }
    class procedure SplitNode(constref aKey: TKey; aRoot: PNode; out L, R: PNode); static;
    class function  MergeNode(L, R: PNode): PNode; static;
    class procedure AddNode(var aRoot: PNode; aNode: PNode); static;
    class function  RemoveNode(constref aKey: TKey; var aRoot: PNode): Boolean; static;
    class function  RemoveNode(constref aKey: TKey; var aRoot: PNode; out v: TValue): Boolean; static;
    class operator  Initialize(var aTreap: TGLiteTreap);
    class operator  Finalize(var aTreap: TGLiteTreap);
    class operator  Copy(constref aSrc: TGLiteTreap; var aDst: TGLiteTreap);
    class operator  AddRef(var aTreap: TGLiteTreap);
  public
    { splits aTreap so that L will contain all keys < aKey and  R will contain all keys >= aKey;
      aTreap becomes empty }
    class procedure Split(constref aKey: TKey; var aTreap: TGLiteTreap; out L, R: TGLiteTreap); static;
    function  IsEmpty: Boolean; inline;             //O(1)
    procedure Clear;                                //O(N)
    function  ToArray: TEntryArray;                 //O(N)
    function  Find(constref aKey: TKey): PNode;     //O(LogN)
    function  CountOf(constref aKey: TKey): SizeInt;//O(N)
    function  Add(constref aKey: TKey): PNode;      //O(LogN)
    function  Remove(constref aKey: TKey): Boolean; //O(LogN)
    function  Remove(constref aKey: TKey; out aValue: TValue): Boolean; //O(LogN)
  { splits treap so that aTreap will contain all elements with keys >= aKey }
    procedure Split(constref aKey: TKey; out aTreap: TGLiteTreap);//O(LogN)
    property  Root: PNode read FRoot;               //O(1)
    property  Count: SizeInt read GetCount;         //O(N)
    property  Height: SizeInt read GetHeight;       //O(N)
  end;

  { TGLiteIdxTreap implements randomized Cartesian BST which allows indexing access
      (IOW rank and N-th order statistics)
      on assignment and when passed by value, the whole treap is copied;
        functor TCmpRel (comparision relation) must provide:
          function Compare([const[ref]] L, R: TKey): SizeInt; }
  generic TGLiteIdxTreap<TKey, TValue, TCmpRel> = record
  public
  type
    PNode = ^TNode;
    TNode = record
    private
      FLeft,
      FRight: PNode;
      FKey: TKey;
      FPrio: SizeUInt;
      FSize: SizeInt;
    public
      Value: TValue;
      property Left: PNode read FLeft;
      property Right: PNode read FRight;
      property Key: TKey read FKey;
      property Size: SizeInt read FSize;
    end;

    TUtil       = specialize TGIndexedBstUtil<TKey, TNode, TCmpRel>;
    TOnVisit    = TUtil.TOnVisit;
    TNestVisit  = TUtil.TNestVisit;
    TEntry      = specialize TGMapEntry<TKey, TValue>;
    TEntryArray = array of TEntry;

  private
    FRoot: PNode;
    function  GetCount: SizeInt; inline;
    function  GetHeight: SizeInt;
    function  GetItem(aIndex: SizeInt): PNode; inline;
    procedure CheckIndexRange(aIndex: SizeInt); inline;
    class function  NewNode(constref aKey: TKey): PNode; static;
    class function  CopyTree(aRoot: PNode): PNode; static;
    class procedure UpdateSize(aNode: PNode); static; inline;
    class procedure SplitNode(constref aKey: TKey; aRoot: PNode; out L, R: PNode); static;
    class function  MergeNode(L, R: PNode): PNode; static;
    class procedure AddNode(var aRoot: PNode; aNode: PNode); static;
    class function  RemoveNode(constref aKey: TKey; var aRoot: PNode): Boolean; static;
    class function  RemoveNode(constref aKey: TKey; var aRoot: PNode; out v: TValue): Boolean; static;
    class operator  Initialize(var aTreap: TGLiteIdxTreap);
    class operator  Finalize(var aTreap: TGLiteIdxTreap);
    class operator  Copy(constref aSrc: TGLiteIdxTreap; var aDst: TGLiteIdxTreap);
    class operator  AddRef(var aTreap: TGLiteIdxTreap); inline;
  public
  { splits aTreap so that L will contain all keys < aKey and  R will contain all keys >= aKey;
    aTreap becomes empty }
    class procedure Split(constref aKey: TKey; var aTreap: TGLiteIdxTreap; out L, R: TGLiteIdxTreap); static;
    function  IsEmpty: Boolean; inline;              //O(1)
    procedure Clear;                                 //O(N)
    function  ToArray: TEntryArray;                  //O(N)
    function  Find(constref aKey: TKey): PNode;      //O(LogN)
    function  IndexOf(constref aKey: TKey): SizeInt; inline;//O(LogN)
    function  CountOf(constref aKey: TKey): SizeInt; //O(LogN)
    function  Add(constref aKey: TKey): PNode;       //O(LogN)
    function  Remove(constref aKey: TKey): Boolean;  //O(LogN)
    function  Remove(constref aKey: TKey; out aValue: TValue): Boolean;//O(LogN)
  { splits treap so that aTreap will contain all elements with keys >= aKey }
    procedure Split(constref aKey: TKey; out aTreap: TGLiteIdxTreap);  //O(LogN)
    property  Root: PNode read FRoot;                //O(1)
    property  Count: SizeInt read GetCount;          //O(1)
    property  Height: SizeInt read GetHeight;        //O(N)
    property  Items[aIndex: SizeInt]: PNode read GetItem; default;//O(LogN)
  end;

  { TGLiteSegmentTreap implements randomized Cartesian BST with unique keys which allows
    indexing access and allows find the value of the monoid function on an arbitrary
    range of keys in O(log N); on assignment and when passed by value, the whole treap is copied;
      functor TCmpRel (comparision relation) must provide:
        function Compare([const[ref]] L, R: TKey): SizeInt;
      functor TValMonoid must provide:
        field/property/function Identity: TValue; - neutral element of the monoid;
        associative dyadic function BinOp([const[ref]] L, R: TValue): TValue; }
  generic TGLiteSegmentTreap<TKey, TValue, TCmpRel, TValMonoid> = record
  public
  type
    TEntry      = specialize TGMapEntry<TKey, TValue>;
    TEntryArray = array of TEntry;

  private
  type
    PNode = ^TNode;
    TNode = record
      Left,
      Right: PNode;
      Key: TKey;
      Prio: SizeUInt;
      Size: SizeInt;
      CacheVal,
      Value: TValue;
    end;
    TUtil = specialize TGIndexedBstUtil<TKey, TNode, TCmpRel>;

  var
    FRoot: PNode;
    function  GetCount: SizeInt; inline;
    function  GetHeight: SizeInt; inline;
    function  GetValue(const aKey: TKey): TValue;
    function  GetEntry(aIndex: SizeInt): TEntry;
    procedure SetValue(const aKey: TKey; const aValue: TValue);
    procedure CheckIndexRange(aIndex: SizeInt); //inline;

    class function  NewNode(constref aKey: TKey; constref aValue: TValue): PNode; static;
    class function  CopyTree(aRoot: PNode): PNode; static;
    class procedure UpdateNode(aNode: PNode); static; inline;
    class procedure UpdateCache(aNode: PNode); static; inline;
    class function  UpdateValue(aRoot: PNode; constref aKey: TKey; constref aValue: TValue): Boolean; static;
    class procedure SplitNode(constref aKey: TKey; aRoot: PNode; out L, R: PNode); static;
    class function  MergeNode(L, R: PNode): PNode; static;
    class procedure AddNode(var aRoot: PNode; aNode: PNode); static;
    class function  RemoveNode(constref aKey: TKey; var aRoot: PNode): Boolean; static;
    class function  RemoveNode(constref aKey: TKey; var aRoot: PNode; out v: TValue): Boolean; static;
    class operator  Initialize(var aTreap: TGLiteSegmentTreap);
    class operator  Finalize(var aTreap: TGLiteSegmentTreap);
    class operator  Copy(constref aSrc: TGLiteSegmentTreap; var aDst: TGLiteSegmentTreap);
    class operator  AddRef(var aTreap: TGLiteSegmentTreap); inline;
  public
    class procedure Split(constref aKey: TKey; var aTreap: TGLiteSegmentTreap;
                          out L, R: TGLiteSegmentTreap); static;
    function  IsEmpty: Boolean; inline;                        //O(1)
    procedure Clear;                                           //O(N)
    function  ToArray: TEntryArray;                            //O(N)
    function  Contains(constref aKey: TKey): Boolean;          //O(LogN)
    function  Find(constref aKey: TKey; out aValue: TValue): Boolean;    //O(LogN)
    function  IndexOf(constref aKey: TKey): SizeInt; inline;   //O(LogN)
    function  Add(constref aKey: TKey; constref aValue: TValue): Boolean;//O(LogN)
    function  Add(constref e: TEntry): Boolean; inline;        //O(LogN)
    function  Remove(constref aKey: TKey): Boolean;            //O(LogN)
    function  Remove(constref aKey: TKey; out aValue: TValue): Boolean;  //O(LogN)
    procedure Split(constref aKey: TKey; out aTreap: TGLiteSegmentTreap);//O(LogN)
  { returns value of the monoid function on the segment[L, R](indices);
    raises exception if L or R out of bounds }
    function  RangeQueryI(L, R: SizeInt): TValue;              //O(LogN)
  { returns value of the monoid function on the half-open interval[L, R) }
    function  RangeQuery(constref L, R: TKey): TValue;         //O(LogN)
  { returns value of the monoid function on the segment[0, aIndex](indices);
    raises exception if aIndex out of bounds }
    function  HeadQueryI(aIndex: SizeInt): TValue;             //O(LogN)
  { returns value of the monoid function on the half-open interval[Lowest key, aKey) }
    function  HeadQuery(constref aKey: TKey): TValue;          //O(LogN)
  { returns value of the monoid function on the segment[aIndex, Pred(Count)](indices);
    raises exception if aIndex out of bounds }
    function  TailQueryI(aIndex: SizeInt): TValue;             //O(LogN)
  { returns value of the monoid function on the segment[aKey, Highest key] }
    function  TailQuery(constref aKey: TKey): TValue;          //O(LogN)
    property  Count: SizeInt read GetCount;                    //O(1)
    property  Height: SizeInt read GetHeight;                  //O(N)
    property  Entries[aIndex: SizeInt]: TEntry read GetEntry;  //O(LogN)
  { if not contains aKey then read returns TValMonoid.Identity }
    property  Values[const aKey: TKey]: TValue read GetValue write SetValue; default;//O(LogN)
  end;

  { TGLiteImplicitTreap implements randomized Cartesian tree which mimics
    an array with most operations in O(LogN); on assignment and when passed by value,
    the whole treap is copied; }
  generic TGLiteImplicitTreap<T> = record
  public
  type
    TArray = array of T;

  private
  type
    PNode = ^TNode;
    TNode = record
    private
      Left,
      Right: PNode;
      Prio: SizeUInt;
      Size: SizeInt;
      Value: T;
      property Key: SizeInt read Size;
    end;
    TUtil = specialize TGIndexedBstUtil<SizeInt, TNode, SizeInt>;

  var
    FRoot: PNode;
    function  GetCount: SizeInt; inline;
    function  GetHeight: SizeInt;
    function  GetItem(aIndex: SizeInt): T;
    procedure SetItem(aIndex: SizeInt; const aValue: T);
    procedure CheckIndexRange(aIndex: SizeInt); //inline;
    procedure CheckInsertRange(aIndex: SizeInt); //inline;
    class function  NewNode(constref aValue: T): PNode; static; inline;
    class function  CopyTree(aRoot: PNode): PNode; static;
    class procedure UpdateSize(aNode: PNode); static; inline;
    class procedure SplitNode(aIdx: SizeInt; aRoot: PNode; out L, R: PNode); static;
    class function  MergeNode(L, R: PNode): PNode; static;
    class procedure DeleteNode(aIndex: SizeInt; var aRoot: PNode; out aValue: T); static;
    class operator  Initialize(var aTreap: TGLiteImplicitTreap);
    class operator  Finalize(var aTreap: TGLiteImplicitTreap);
    class operator  Copy(constref aSrc: TGLiteImplicitTreap; var aDst: TGLiteImplicitTreap);
    class operator  AddRef(var aTreap: TGLiteImplicitTreap); inline;
  public
    class procedure Split(aIndex: SizeInt; var aTreap: TGLiteImplicitTreap;
                          out L, R: TGLiteImplicitTreap); static;
    function  IsEmpty: Boolean; inline;                   //O(1)
    procedure Clear;                                      //O(N)
    function  ToArray: TArray;                            //O(N)
    function  Add(constref aValue: T): SizeInt;           //O(LogN)
    procedure Insert(aIndex: SizeInt; constref aValue: T);//O(LogN)
    procedure Insert(aIndex: SizeInt; var aTreap: TGLiteImplicitTreap);
    function  Delete(aIndex: SizeInt): T;                 //O(LogN)
    procedure Split(aIndex: SizeInt; out aTreap: TGLiteImplicitTreap);
    procedure Split(aIndex, aCount: SizeInt; out aTreap: TGLiteImplicitTreap);//O(LogN)
    procedure Merge(var aTreap: TGLiteImplicitTreap);     //O(LogN)
    procedure RotateLeft(aDist: SizeInt);                 //O(LogN)
    procedure RotateRight(aDist: SizeInt);                //O(LogN)
    property  Count: SizeInt read GetCount;               //O(1)
    property  Height: SizeInt read GetHeight;             //O(N)
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;  //O(LogN)
  end;

  { TGLiteImplSegmentTreap implements randomized Cartesian tree which mimics an array;
    it allows:
      - add an element to the array in O(log N);
      - update a single element of an array in O(log N);
      - add an arbitrary range of elements to the array in O(log N);
      - find the value of the monoid function on an arbitrary range of array elements in O(log N);
      functor TMonoid must provide:
        field/property/function Identity: T; - neutral element of the monoid;
        associative dyadic function BinOp([const[ref]] L, R: T): T;
    on assignment and when passed by value, the whole treap is copied; }
  generic TGLiteImplSegmentTreap<T, TMonoid> = record
  public
  type
    TArray = array of T;

  private
  type
    PNode = ^TNode;
    TNode = record
    private
      Left,
      Right: PNode;
      Prio: SizeUInt;
      Size: SizeInt;
      CacheVal,
      Value: T;
      property Key: SizeInt read Size;
    end;
    TUtil = specialize TGIndexedBstUtil<SizeInt, TNode, SizeInt>;

  var
    FRoot: PNode;
    function  GetCount: SizeInt; inline;
    function  GetHeight: SizeInt;
    function  GetItem(aIndex: SizeInt): T;
    procedure SetItem(aIndex: SizeInt; const aValue: T);
    procedure CheckIndexRange(aIndex: SizeInt); //inline;
    procedure CheckInsertRange(aIndex: SizeInt); //inline;
    class function  NewNode(constref aValue: T): PNode; static;
    class function  CopyTree(aRoot: PNode): PNode; static;
    class procedure UpdateNode(aNode: PNode); static; inline;
    class procedure UpdateCache(aNode: PNode); static; inline;
    class procedure UpdateValue(aIndex: SizeInt; aRoot: PNode; constref aValue: T); static;
    class procedure SplitNode(aIdx: SizeInt; aRoot: PNode; out L, R: PNode); static;
    class function  MergeNode(L, R: PNode): PNode; static;
    class procedure DeleteNode(aIndex: SizeInt; var aRoot: PNode; out aValue: T); static;
    class operator  Initialize(var aTreap: TGLiteImplSegmentTreap);
    class operator  Finalize(var aTreap: TGLiteImplSegmentTreap);
    class operator  Copy(constref aSrc: TGLiteImplSegmentTreap; var aDst: TGLiteImplSegmentTreap);
    class operator  AddRef(var aTreap: TGLiteImplSegmentTreap); inline;
  public
    class procedure Split(aIndex: SizeInt; var aTreap: TGLiteImplSegmentTreap;
                          out L, R: TGLiteImplSegmentTreap); static;
    function  IsEmpty: Boolean; inline;                    //O(1)
    procedure Clear;                                       //O(N)
    function  ToArray: TArray;                             //O(N)
    function  Add(constref aValue: T): SizeInt;            //O(LogN)
    procedure Insert(aIndex: SizeInt; constref aValue: T); //O(LogN)
    procedure Insert(aIndex: SizeInt; var aTreap: TGLiteImplSegmentTreap);       //O(LogN)
    function  Delete(aIndex: SizeInt): T;                  //O(LogN)
    procedure Split(aIndex: SizeInt; out aTreap: TGLiteImplSegmentTreap);        //O(LogN)
    procedure Split(aIndex, aCount: SizeInt; out aTreap: TGLiteImplSegmentTreap);//O(LogN)
    procedure Merge(var aTreap: TGLiteImplSegmentTreap);   //O(LogN)
    procedure RotateLeft(aDist: SizeInt);                  //O(LogN)
    procedure RotateRight(aDist: SizeInt);                 //O(LogN)
  { returns value of the monoid function on the segment[L, R];
    raises exception if L or R out of bounds }
    function  RangeQuery(L, R: SizeInt): T;                //O(LogN)
  { returns value of the monoid function on the segment[0, aIndex];
    raises exception if aIndex out of bounds }
    function  HeadQuery(aIndex: SizeInt): T;               //O(LogN)
  { returns value of the monoid function on the segment[aIndex, Pred(Count)];
    raises exception if aIndex out of bounds }
    function  TailQuery(aIndex: SizeInt): T;               //O(LogN)
    property  Count: SizeInt read GetCount;                //O(1)
    property  Height: SizeInt read GetHeight;              //O(N)
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;     //O(LogN)
  end;

implementation
{$B-}{$COPERATORS ON}

{ TGBstUtil }

class function TGBstUtil.GetTreeSize(aNode: PNode): SizeInt;
var
  Size: SizeInt = 0;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Inc(Size);
        Visit(aNode^.Left);
        Visit(aNode^.Right);
      end;
  end;
begin
  Visit(aNode);
  Result := Size;
end;

class function TGBstUtil.GetHeight(aNode: PNode): SizeInt;
begin
  if aNode <> nil then
    Result := Succ(Math.Max(GetHeight(aNode^.Left), GetHeight(aNode^.Right)))
  else
    Result := 0;
end;

class function TGBstUtil.GetLowest(aRoot: PNode): PNode;
begin
  Result := aRoot;
  if Result <> nil then
    while Result^.Left <> nil do
      Result := Result^.Left;
end;

class function TGBstUtil.GetHighest(aRoot: PNode): PNode;
begin
  Result := aRoot;
  if Result <> nil then
    while Result^.Right <> nil do
      Result := Result^.Right;
end;

class function TGBstUtil.FindKey(aRoot: PNode; constref aKey: TKey): PNode;
begin
  Result := aRoot;
  while Result <> nil do
    case SizeInt(TCmpRel.Compare(aKey, Result^.Key)) of
      System.Low(SizeInt)..-1: Result := Result^.Left;
      1..System.High(SizeInt): Result := Result^.Right;
    else
      exit;
    end;
end;

class function TGBstUtil.GetLess(aRoot: PNode; constref aKey: TKey): PNode;
var
  Node: PNode;
begin
  Node := aRoot;
  Result := nil;
  while Node <> nil do
    if TCmpRel.Compare(aKey, Node^.Key) > 0 then
      begin
        Result := Node;
        Node := Node^.Right;
      end
    else
      Node := Node^.Left;
end;

class function TGBstUtil.GetLessOrEqual(aRoot: PNode; constref aKey: TKey): PNode;
var
  Node: PNode;
begin
  Node := aRoot;
  Result := nil;
  while Node <> nil do
    if TCmpRel.Compare(aKey, Node^.Key) >= 0 then
      begin
        Result := Node;
        Node := Node^.Right;
      end
    else
      Node := Node^.Left;
end;

class function TGBstUtil.GetGreater(aRoot: PNode; constref aKey: TKey): PNode;
var
  Node: PNode;
begin
  Node := aRoot;
  Result := nil;
  while Node <> nil do
    if TCmpRel.Compare(aKey, Node^.Key) < 0 then
      begin
        Result := Node;
        Node := Node^.Left;
      end
    else
      Node := Node^.Right;
end;

class function TGBstUtil.GetGreaterOrEqual(aRoot: PNode; constref aKey: TKey): PNode;
var
  Node: PNode;
begin
  Node := aRoot;
  Result := nil;
  while Node <> nil do
    if TCmpRel.Compare(aKey, Node^.Key) <= 0 then
      begin
        Result := Node;
        Node := Node^.Left;
      end
    else
      Node := Node^.Right;
end;

class procedure TGBstUtil.ClearTree(aNode: PNode);
begin
  if aNode <> nil then
    begin
      ClearTree(aNode^.Left);
      ClearTree(aNode^.Right);
      //if IsManagedType(TNode) then
        aNode^ := Default(TNode);
      System.FreeMem(aNode);
    end;
end;

class procedure TGBstUtil.FreeNode(aNode: PNode);
begin
  //if IsManagedType(TNode) then
    aNode^ := Default(TNode);
  System.FreeMem(aNode);
end;

class function TGBstUtil.PreOrderTraversal(aRoot: PNode; aOnVisit: TOnVisit): SizeInt;
var
  Visited: SizeInt = 0;
  Goon: Boolean = True;

  procedure Visit(aNode: PNode);
  begin
    if (aNode <> nil) and Goon then
      begin
        if aOnVisit <> nil then
          begin
            aOnVisit(aNode, Goon);
            Inc(Visited);
          end;
        Visit(aNode^.Left);
        Visit(aNode^.Right);
      end;
  end;

begin
  Visit(aRoot);
  Result := Visited;
end;

class function TGBstUtil.PreOrderTraversal(aRoot: PNode; aOnVisit: TNestVisit): SizeInt;
var
  Visited: SizeInt = 0;
  Goon: Boolean = True;

  procedure Visit(aNode: PNode);
  begin
    if (aNode <> nil) and Goon then
      begin
        if aOnVisit <> nil then
          begin
            aOnVisit(aNode, Goon);
            Inc(Visited);
          end;
        Visit(aNode^.Left);
        Visit(aNode^.Right);
      end;
  end;

begin
  Visit(aRoot);
  Result := Visited;
end;

class function TGBstUtil.InOrderTraversal(aRoot: PNode; aOnVisit: TOnVisit): SizeInt;
var
  Visited: SizeInt = 0;
  Goon: Boolean = True;

  procedure Visit(aNode: PNode);
  begin
    if (aNode <> nil) and Goon then
      begin
        Visit(aNode^.Left);
        if (aOnVisit <> nil) and Goon then
          begin
            aOnVisit(aNode, Goon);
            Inc(Visited);
          end;
        Visit(aNode^.Right);
      end;
  end;

begin
  Visit(aRoot);
  Result := Visited;
end;

class function TGBstUtil.InOrderTraversal(aRoot: PNode; aOnVisit: TNestVisit): SizeInt;
var
  Visited: SizeInt = 0;
  Goon: Boolean = True;

  procedure Visit(aNode: PNode);
  begin
    if (aNode <> nil) and Goon then
      begin
        Visit(aNode^.Left);
        if (aOnVisit <> nil) and Goon then
          begin
            aOnVisit(aNode, Goon);
            Inc(Visited);
          end;
        Visit(aNode^.Right);
      end;
  end;

begin
  Visit(aRoot);
  Result := Visited;
end;

class function TGBstUtil.PostOrderTraversal(aRoot: PNode; aOnVisit: TOnVisit): SizeInt;
var
  Visited: SizeInt = 0;
  Goon: Boolean = True;

  procedure Visit(aNode: PNode);
  begin
    if (aNode <> nil) and Goon then
      begin
        Visit(aNode^.Left);
        Visit(aNode^.Right);
        if (aOnVisit <> nil) and Goon then
          begin
            aOnVisit(aNode, Goon);
            Inc(Visited);
          end;
      end;
  end;

begin
  Visit(aRoot);
  Result := Visited;
end;

class function TGBstUtil.PostOrderTraversal(aRoot: PNode; aOnVisit: TNestVisit): SizeInt;
var
  Visited: SizeInt = 0;
  Goon: Boolean = True;

  procedure Visit(aNode: PNode);
  begin
    if (aNode <> nil) and Goon then
      begin
        Visit(aNode^.Left);
        Visit(aNode^.Right);
        if (aOnVisit <> nil) and Goon then
          begin
            aOnVisit(aNode, Goon);
            Inc(Visited);
          end;
      end;
  end;

begin
  Visit(aRoot);
  Result := Visited;
end;

{ TGIndexedBstUtil }

class function TGIndexedBstUtil.GetNodeSize(aNode: PNode): SizeInt;
begin
  if aNode <> nil then
    Result := aNode^.Size
  else
    Result := 0;
end;

class function TGIndexedBstUtil.GetByIndex(aRoot: PNode; aIndex: SizeInt): PNode;
var
  LSize: SizeInt;
begin
  Result := aRoot;
  while Result <> nil do
    begin
      LSize := GetNodeSize(Result^.Left);
      if LSize < aIndex then
        begin
          Result := Result^.Right;
          aIndex -= Succ(LSize);
        end
      else
        if LSize > aIndex then
          Result := Result^.Left
        else
          exit;
    end;
end;

class function TGIndexedBstUtil.GetKeyIndex(aRoot: PNode; constref aKey: TKey): SizeInt;
var
  Pos: SizeInt = 0;
begin
  while aRoot <> nil do
    case SizeInt(TCmpRel.Compare(aKey, aRoot^.Key)) of
      System.Low(SizeInt)..-1: aRoot := aRoot^.Left;
      1..System.High(SizeInt):
        begin
          Pos += Succ(GetNodeSize(aRoot^.Left));
          aRoot := aRoot^.Right;
        end;
    else
      exit(Pos + GetNodeSize(aRoot^.Left));
    end;
  Result := NULL_INDEX;
end;

{ TGLiteTreap }

function TGLiteTreap.GetCount: SizeInt;
begin
  if FRoot <> nil then
    exit(TUtil.GetTreeSize(FRoot));
  Result := 0;
end;

function TGLiteTreap.GetHeight: SizeInt;
begin
  Result := TUtil.GetHeight(FRoot);
end;

class function TGLiteTreap.NewNode(constref aKey: TKey): PNode;
begin
  Result := System.GetMem(SizeOf(TNode));
  System.FillChar(Result^, SizeOf(TNode), 0);
  Result^.FKey := aKey;
  Result^.FPrio := {$IFDEF CPU64}BJNextRandom64{$ELSE}BJNextRandom{$ENDIF};
end;

class function TGLiteTreap.CopyTree(aRoot: PNode): PNode;
var
  Tmp: TGLiteTreap;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.FLeft);
        Tmp.Add(aNode^.Key)^.Value := aNode^.Value;
        Visit(aNode^.FRight);
      end;
  end;
begin
  Tmp.Clear;
  if aRoot <> nil then
    begin
      Visit(aRoot);
      Result := Tmp.FRoot;
      Tmp.FRoot := nil;
    end
  else
    Result := nil;
end;

class procedure TGLiteTreap.SplitNode(constref aKey: TKey; aRoot: PNode; out L, R: PNode);
begin
  if aRoot <> nil then
    begin
      if TCmpRel.Compare(aRoot^.Key, aKey) < 0 then
        begin
          L := aRoot;
          SplitNode(aKey, L^.FRight, L^.FRight, R);
        end
      else
        begin
          R := aRoot;
          SplitNode(aKey, R^.FLeft, L, R^.FLeft);
        end;
      exit;
    end;
  L := nil;
  R := nil;
end;

class function TGLiteTreap.MergeNode(L, R: PNode): PNode;
begin
  if L = nil then
    Result := R
  else
    if R = nil then
      Result := L
    else
      if L^.FPrio > R^.FPrio then
        begin
          L^.FRight := MergeNode(L^.FRight, R);
          Result := L;
        end
      else
        begin
          R^.FLeft := MergeNode(L, R^.FLeft);
          Result := R;
        end;
end;

class procedure TGLiteTreap.AddNode(var aRoot: PNode; aNode: PNode);
begin
  if aRoot <> nil then
    begin
      if aRoot^.FPrio < aNode^.FPrio then
        begin
          SplitNode(aNode^.Key, aRoot, aNode^.FLeft, aNode^.FRight);
          aRoot := aNode;
        end
      else
        if TCmpRel.Compare(aNode^.Key, aRoot^.Key) < 0 then
          AddNode(aRoot^.FLeft, aNode)
        else
          AddNode(aRoot^.FRight, aNode);
    end
  else
    aRoot := aNode;
end;


class function TGLiteTreap.RemoveNode(constref aKey: TKey; var aRoot: PNode): Boolean;
var
  Found: PNode;
begin
  if aRoot <> nil then
    case SizeInt(TCmpRel.Compare(aKey, aRoot^.Key)) of
      System.Low(SizeInt)..-1: exit(RemoveNode(aKey, aRoot^.FLeft));
      1..System.High(SizeInt): exit(RemoveNode(aKey, aRoot^.FRight));
    else
      Found := aRoot;
      aRoot := MergeNode(aRoot^.FLeft, aRoot^.FRight);
      TUtil.FreeNode(Found);
      exit(True);
    end;
  Result := False;
end;

class function TGLiteTreap.RemoveNode(constref aKey: TKey; var aRoot: PNode; out v: TValue): Boolean;
var
  Found: PNode;
begin
  if aRoot <> nil then
    case SizeInt(TCmpRel.Compare(aKey, aRoot^.Key)) of
      System.Low(SizeInt)..-1: exit(RemoveNode(aKey, aRoot^.FLeft, v));
      1..System.High(SizeInt): exit(RemoveNode(aKey, aRoot^.FRight, v));
    else
      Found := aRoot;
      aRoot := MergeNode(aRoot^.FLeft, aRoot^.FRight);
      v := Found^.Value;
      TUtil.FreeNode(Found);
      exit(True);
    end;
  Result := False;
end;

class operator TGLiteTreap.Initialize(var aTreap: TGLiteTreap);
begin
  aTreap.FRoot := nil;
end;

class operator TGLiteTreap.Finalize(var aTreap: TGLiteTreap);
begin
  aTreap.Clear;
end;

class operator TGLiteTreap.Copy(constref aSrc: TGLiteTreap; var aDst: TGLiteTreap);
begin
  aDst.Clear;
  if aSrc.FRoot <> nil then
    aDst.FRoot := CopyTree(aSrc.FRoot);
end;

class operator TGLiteTreap.AddRef(var aTreap: TGLiteTreap);
begin
  if aTreap.FRoot <> nil then
    aTreap.FRoot := CopyTree(aTreap.FRoot);
end;

class procedure TGLiteTreap.Split(constref aKey: TKey; var aTreap: TGLiteTreap; out L, R: TGLiteTreap);
begin
  if aTreap.FRoot = nil then
    exit;
  SplitNode(aKey, aTreap.FRoot, L.FRoot, R.FRoot);
  aTreap.FRoot := nil;
end;

function TGLiteTreap.IsEmpty: Boolean;
begin
  Result := FRoot = nil;
end;

procedure TGLiteTreap.Clear;
begin
  if FRoot <> nil then
    TUtil.ClearTree(FRoot);
  FRoot := nil;
end;

function TGLiteTreap.ToArray: TEntryArray;
var
  a: TEntryArray = nil;
  I: Integer = 0;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.FLeft);
        if System.Length(a) = I then
          System.SetLength(a, I * 2);
        a[I] := TEntry.Create(aNode^.Key, aNode^.Value);
        Inc(I);
        Visit(aNode^.FRight);
      end;
  end;
begin
  if FRoot <> nil then
    begin
      System.SetLength(a, ARRAY_INITIAL_SIZE);
      Visit(FRoot);
      System.SetLength(a, I);
    end;
  Result := a;
end;

function TGLiteTreap.Find(constref aKey: TKey): PNode;
begin
  if FRoot <> nil then
    exit(TUtil.FindKey(FRoot, aKey));
  Result := nil;
end;

function TGLiteTreap.CountOf(constref aKey: TKey): SizeInt;
var
  L, M, R, Gt: PNode;
begin
  if FRoot <> nil then
    begin
      Gt := TUtil.GetGreater(FRoot, aKey);
      SplitNode(aKey, FRoot, L, R);
      if Gt <> nil then
        begin
          SplitNode(Gt^.Key, R, M, R);
          Result := TUtil.GetTreeSize(M);
          FRoot := MergeNode(MergeNode(L, M), R);
        end
      else
        begin
          Result := TUtil.GetTreeSize(R);
          FRoot := MergeNode(L, R);
        end;
    end
  else
    Result := 0;
end;

function TGLiteTreap.Add(constref aKey: TKey): PNode;
begin
  Result := NewNode(aKey);
  if FRoot <> nil then
    AddNode(FRoot, Result)
  else
    FRoot := Result;
end;

function TGLiteTreap.Remove(constref aKey: TKey): Boolean;
begin
  if FRoot <> nil then
    Result := RemoveNode(aKey, FRoot)
  else
    Result := False;
end;

function TGLiteTreap.Remove(constref aKey: TKey; out aValue: TValue): Boolean;
begin
  if FRoot <> nil then
    Result := RemoveNode(aKey, FRoot, aValue)
  else
    Result := False;
end;

procedure TGLiteTreap.Split(constref aKey: TKey; out aTreap: TGLiteTreap);
begin
  if FRoot <> nil then
    SplitNode(aKey, FRoot, FRoot, aTreap.FRoot);
end;

{ TGLiteIdxTreap }

function TGLiteIdxTreap.GetCount: SizeInt;
begin
  Result := TUtil.GetNodeSize(FRoot);
end;

function TGLiteIdxTreap.GetHeight: SizeInt;
begin
  Result := TUtil.GetHeight(FRoot);
end;

function TGLiteIdxTreap.GetItem(aIndex: SizeInt): PNode;
begin
  Result := TUtil.GetByIndex(FRoot, aIndex);
end;

procedure TGLiteIdxTreap.CheckIndexRange(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) >= SizeUInt(TUtil.GetNodeSize(FRoot)) then
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

class function TGLiteIdxTreap.NewNode(constref aKey: TKey): PNode;
begin
  Result := System.GetMem(SizeOf(TNode));
  System.FillChar(Result^, SizeOf(TNode), 0);
  Result^.FKey := aKey;
  Result^.FPrio := {$IFDEF CPU64}BJNextRandom64{$ELSE}BJNextRandom{$ENDIF};
  Result^.FSize := 1;
end;

class function TGLiteIdxTreap.CopyTree(aRoot: PNode): PNode;
var
  Tmp: TGLiteIdxTreap;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.FLeft);
        Tmp.Add(aNode^.Key)^.Value := aNode^.Value;
        Visit(aNode^.FRight);
      end;
  end;
begin
  Tmp.Clear;
  if aRoot <> nil then
    begin
      Visit(aRoot);
      Result := Tmp.FRoot;
      Tmp.FRoot := nil;
    end
  else
    Result := nil;
end;

class procedure TGLiteIdxTreap.UpdateSize(aNode: PNode);
begin
  with aNode^ do
    begin
      FSize := 1;
      if Left <> nil then
        FSize += Left^.FSize;
      if Right <> nil then
        FSize += Right^.FSize;
    end;
end;

class procedure TGLiteIdxTreap.SplitNode(constref aKey: TKey; aRoot: PNode; out L, R: PNode);
begin
  if aRoot <> nil then
    begin
      if TCmpRel.Compare(aRoot^.Key, aKey) < 0 then
        begin
          L := aRoot;
          SplitNode(aKey, L^.FRight, L^.FRight, R);
        end
      else
        begin
          R := aRoot;
          SplitNode(aKey, R^.FLeft, L, R^.FLeft);
        end;
      UpdateSize(aRoot);
      exit;
    end;
  L := nil;
  R := nil;
end;

class function TGLiteIdxTreap.MergeNode(L, R: PNode): PNode;
begin
  if L = nil then
    Result := R
  else
    if R = nil then
      Result := L
    else
      begin
        if L^.FPrio > R^.FPrio then
          begin
            L^.FRight := MergeNode(L^.FRight, R);
            Result := L;
          end
        else
          begin
            R^.FLeft := MergeNode(L, R^.FLeft);
            Result := R;
          end;
        UpdateSize(Result);
      end;
end;

class procedure TGLiteIdxTreap.AddNode(var aRoot: PNode; aNode: PNode);
begin
  if aRoot <> nil then
    begin
      if aRoot^.FPrio < aNode^.FPrio then
        begin
          SplitNode(aNode^.Key, aRoot, aNode^.FLeft, aNode^.FRight);
          aRoot := aNode;
        end
      else
        if TCmpRel.Compare(aNode^.Key, aRoot^.Key) < 0 then
          AddNode(aRoot^.FLeft, aNode)
        else
          AddNode(aRoot^.FRight, aNode);
      UpdateSize(aRoot);
    end
  else
    aRoot := aNode;
end;

class function TGLiteIdxTreap.RemoveNode(constref aKey: TKey; var aRoot: PNode): Boolean;
var
  Found: PNode;
  c: SizeInt;
begin
  if aRoot <> nil then
    begin
      c := TCmpRel.Compare(aKey, aRoot^.Key);
      if c = 0 then
        begin
          Found := aRoot;
          aRoot := MergeNode(aRoot^.FLeft, aRoot^.FRight);
          TUtil.FreeNode(Found);
          Result := True;
        end
      else
        begin
          if c < 0 then
            Result := RemoveNode(aKey, aRoot^.FLeft)
          else
            Result := RemoveNode(aKey, aRoot^.FRight);
          if Result and (aRoot <> nil) then
            UpdateSize(aRoot);
        end;
    end
  else
    Result := False;
end;

class function TGLiteIdxTreap.RemoveNode(constref aKey: TKey; var aRoot: PNode; out v: TValue): Boolean;
var
  Found: PNode;
  c: SizeInt;
begin
  if aRoot <> nil then
    begin
      c := TCmpRel.Compare(aKey, aRoot^.Key);
      if c = 0 then
        begin
          Found := aRoot;
          aRoot := MergeNode(aRoot^.FLeft, aRoot^.FRight);
          v := Found^.Value;
          TUtil.FreeNode(Found);
          Result := True;
        end
      else
        begin
          if c < 0 then
            Result := RemoveNode(aKey, aRoot^.FLeft, v)
          else
            Result := RemoveNode(aKey, aRoot^.FRight, v);
          if Result and (aRoot <> nil) then
            UpdateSize(aRoot);
        end;
    end
  else
    Result := False;
end;

class operator TGLiteIdxTreap.Initialize(var aTreap: TGLiteIdxTreap);
begin
  aTreap.FRoot := nil;
end;

class operator TGLiteIdxTreap.Finalize(var aTreap: TGLiteIdxTreap);
begin
  aTreap.Clear;
end;

class operator TGLiteIdxTreap.Copy(constref aSrc: TGLiteIdxTreap; var aDst: TGLiteIdxTreap);
begin
  aDst.Clear;
  if aSrc.FRoot <> nil then
    aDst.FRoot := CopyTree(aSrc.FRoot);
end;

class operator TGLiteIdxTreap.AddRef(var aTreap: TGLiteIdxTreap);
begin
  if aTreap.FRoot <> nil then
    aTreap.FRoot := CopyTree(aTreap.FRoot);
end;

class procedure TGLiteIdxTreap.Split(constref aKey: TKey; var aTreap: TGLiteIdxTreap;
  out L, R: TGLiteIdxTreap);
begin
  if aTreap.FRoot = nil then
    exit;
  SplitNode(aKey, aTreap.FRoot, L.FRoot, R.FRoot);
  aTreap.FRoot := nil;
end;

function TGLiteIdxTreap.IsEmpty: Boolean;
begin
  Result := FRoot = nil;
end;

procedure TGLiteIdxTreap.Clear;
begin
  if FRoot <> nil then
    TUtil.ClearTree(FRoot);
  FRoot := nil;
end;

function TGLiteIdxTreap.ToArray: TEntryArray;
var
  a: TEntryArray = nil;
  I: Integer = 0;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.FLeft);
        a[I] := TEntry.Create(aNode^.Key, aNode^.Value);
        Inc(I);
        Visit(aNode^.FRight);
      end;
  end;
begin
  if FRoot <> nil then
    begin
      System.SetLength(a, FRoot^.Size);
      Visit(FRoot);
    end;
  Result := a;
end;

function TGLiteIdxTreap.Find(constref aKey: TKey): PNode;
begin
  if FRoot <> nil then
    exit(TUtil.FindKey(FRoot, aKey));
  Result := nil;
end;

function TGLiteIdxTreap.IndexOf(constref aKey: TKey): SizeInt;
begin
  Result := TUtil.GetKeyIndex(FRoot, aKey);
end;

function TGLiteIdxTreap.CountOf(constref aKey: TKey): SizeInt;
var
  L, M, R, Gt: PNode;
begin
  if FRoot <> nil then
    begin
      Gt := TUtil.GetGreater(FRoot, aKey);
      SplitNode(aKey, FRoot, L, R);
      if Gt <> nil then
        begin
          SplitNode(Gt^.Key, R, M, R);
          Result := TUtil.GetNodeSize(M);
          FRoot := MergeNode(MergeNode(L, M), R);
        end
      else
        begin
          Result := TUtil.GetNodeSize(R);
          FRoot := MergeNode(L, R);
        end;
    end
  else
    Result := 0;
end;

function TGLiteIdxTreap.Add(constref aKey: TKey): PNode;
begin
  Result := NewNode(aKey);
  if FRoot <> nil then
    AddNode(FRoot, Result)
  else
    FRoot := Result;
end;

function TGLiteIdxTreap.Remove(constref aKey: TKey): Boolean;
begin
  if FRoot <> nil then
    Result := RemoveNode(aKey, FRoot)
  else
    Result := False;
end;

function TGLiteIdxTreap.Remove(constref aKey: TKey; out aValue: TValue): Boolean;
begin
  if FRoot <> nil then
    Result := RemoveNode(aKey, FRoot, aValue)
  else
    Result := False;
end;

procedure TGLiteIdxTreap.Split(constref aKey: TKey; out aTreap: TGLiteIdxTreap);
begin
  if FRoot <> nil then
    SplitNode(aKey, FRoot, FRoot, aTreap.FRoot);
end;

{ TGLiteSegmentTreap }

function TGLiteSegmentTreap.GetCount: SizeInt;
begin
  Result := TUtil.GetNodeSize(FRoot);
end;

function TGLiteSegmentTreap.GetHeight: SizeInt;
begin
  Result := TUtil.GetHeight(FRoot);
end;

function TGLiteSegmentTreap.GetValue(const aKey: TKey): TValue;
begin
  if not Find(aKey, Result) then
    Result := TValMonoid.Identity;
end;

function TGLiteSegmentTreap.GetEntry(aIndex: SizeInt): TEntry;
begin
  CheckIndexRange(aIndex);
  with TUtil.GetByIndex(FRoot, aIndex)^ do
    Result := TEntry.Create(Key, Value);
end;

class function TGLiteSegmentTreap.NewNode(constref aKey: TKey; constref aValue: TValue): PNode;
begin
  Result := System.GetMem(SizeOf(TNode));
  System.FillChar(Result^, SizeOf(TNode), 0);
  Result^.Key := aKey;
  Result^.Prio := {$IFDEF CPU64}BJNextRandom64{$ELSE}BJNextRandom{$ENDIF};
  Result^.Size := 1;
  Result^.CacheVal := aValue;
  Result^.Value := aValue;
end;

class function TGLiteSegmentTreap.CopyTree(aRoot: PNode): PNode;
var
  Tmp: TGLiteSegmentTreap;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.Left);
        Tmp.Add(aNode^.Key, aNode^.Value);
        Visit(aNode^.Right);
      end;
  end;
begin
  Tmp.Clear;
  if aRoot <> nil then
    begin
      Visit(aRoot);
      Result := Tmp.FRoot;
      Tmp.FRoot := nil;
    end
  else
    Result := nil;
end;

procedure TGLiteSegmentTreap.SetValue(const aKey: TKey; const aValue: TValue);
begin
  if not Add(aKey, aValue) then
    UpdateValue(FRoot, aKey, aValue);
end;

procedure TGLiteSegmentTreap.CheckIndexRange(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) >= SizeUInt(TUtil.GetNodeSize(FRoot)) then
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

class procedure TGLiteSegmentTreap.UpdateNode(aNode: PNode);
begin
  with aNode^ do
    begin
      Size := 1;
      CacheVal := aNode^.Value;
      if Left <> nil then
        begin
          Size += Left^.Size;
          CacheVal := TValMonoid.BinOp(CacheVal, Left^.CacheVal);
        end;
      if Right <> nil then
        begin
          Size += Right^.Size;
          CacheVal := TValMonoid.BinOp(CacheVal, Right^.CacheVal);
        end;
    end;
end;

class procedure TGLiteSegmentTreap.UpdateCache(aNode: PNode);
begin
  with aNode^ do
    begin
      CacheVal := aNode^.Value;
      if Left <> nil then
        CacheVal := TValMonoid.BinOp(CacheVal, Left^.CacheVal);
      if Right <> nil then
        CacheVal := TValMonoid.BinOp(CacheVal, Right^.CacheVal);
    end;
end;

class function TGLiteSegmentTreap.UpdateValue(aRoot: PNode; constref aKey: TKey;
  constref aValue: TValue): Boolean;
begin
  if aRoot <> nil then
    begin
      case SizeInt(TCmpRel.Compare(aKey, aRoot^.Key)) of
        System.Low(SizeInt)..-1: Result := UpdateValue(aRoot^.Left, aKey, aValue);
        1..System.High(SizeInt): Result := UpdateValue(aRoot^.Right, aKey, aValue);
      else
        aRoot^.Value := aValue;
        Result := True;
      end;
      if Result then
        UpdateCache(aRoot);
    end
  else
    Result := False;
end;

class procedure TGLiteSegmentTreap.SplitNode(constref aKey: TKey; aRoot: PNode; out L, R: PNode);
begin
  if aRoot <> nil then
    begin
      if TCmpRel.Compare(aRoot^.Key, aKey) < 0 then
        begin
          L := aRoot;
          SplitNode(aKey, L^.Right, L^.Right, R);
        end
      else
        begin
          R := aRoot;
          SplitNode(aKey, R^.Left, L, R^.Left);
        end;
      UpdateNode(aRoot);
    end
  else
    begin
      L := nil;
      R := nil;
    end;
end;

class function TGLiteSegmentTreap.MergeNode(L, R: PNode): PNode;
begin
  if L = nil then
    Result := R
  else
    if R = nil then
      Result := L
    else
      begin
        if L^.Prio > R^.Prio then
          begin
            L^.Right := MergeNode(L^.Right, R);
            Result := L;
          end
        else
          begin
            R^.Left := MergeNode(L, R^.Left);
            Result := R;
          end;
        UpdateNode(Result);
      end;
end;

class procedure TGLiteSegmentTreap.AddNode(var aRoot: PNode; aNode: PNode);
begin
  if aRoot <> nil then
    begin
      if aRoot^.Prio < aNode^.Prio then
        begin
          SplitNode(aNode^.Key, aRoot, aNode^.Left, aNode^.Right);
          aRoot := aNode;
        end
      else
        if TCmpRel.Compare(aNode^.Key, aRoot^.Key) < 0 then
          AddNode(aRoot^.Left, aNode)
        else
          AddNode(aRoot^.Right, aNode);
      UpdateNode(aRoot);
    end
  else
    aRoot := aNode;
end;

class function TGLiteSegmentTreap.RemoveNode(constref aKey: TKey; var aRoot: PNode): Boolean;
var
  Found: PNode;
  c: SizeInt;
begin
  if aRoot <> nil then
    begin
      c := TCmpRel.Compare(aKey, aRoot^.Key);
      if c = 0 then
        begin
          Found := aRoot;
          aRoot := MergeNode(aRoot^.Left, aRoot^.Right);
          TUtil.FreeNode(Found);
          Result := True;
        end
      else
        begin
          if c < 0 then
            Result := RemoveNode(aKey, aRoot^.Left)
          else
            Result := RemoveNode(aKey, aRoot^.Right);
          if Result and (aRoot <> nil) then
            UpdateNode(aRoot);
        end;
    end
  else
    Result := False;
end;

class function TGLiteSegmentTreap.RemoveNode(constref aKey: TKey; var aRoot: PNode; out v: TValue): Boolean;
var
  Found: PNode;
  c: SizeInt;
begin
  if aRoot <> nil then
    begin
      c := TCmpRel.Compare(aKey, aRoot^.Key);
      if c = 0 then
        begin
          Found := aRoot;
          aRoot := MergeNode(aRoot^.Left, aRoot^.Right);
          v := Found^.Value;
          TUtil.FreeNode(Found);
          Result := True;
        end
      else
        begin
          if c < 0 then
            Result := RemoveNode(aKey, aRoot^.Left, v)
          else
            Result := RemoveNode(aKey, aRoot^.Right, v);
          if Result and (aRoot <> nil) then
            UpdateNode(aRoot);
        end;
    end
  else
    Result := False;
end;

class operator TGLiteSegmentTreap.Initialize(var aTreap: TGLiteSegmentTreap);
begin
  aTreap.FRoot := nil;
end;

class operator TGLiteSegmentTreap.Finalize(var aTreap: TGLiteSegmentTreap);
begin
  aTreap.Clear;
end;

class operator TGLiteSegmentTreap.Copy(constref aSrc: TGLiteSegmentTreap; var aDst: TGLiteSegmentTreap);
begin
  aDst.Clear;
  if aSrc.FRoot <> nil then
    aDst.FRoot := CopyTree(aSrc.FRoot);
end;

class operator TGLiteSegmentTreap.AddRef(var aTreap: TGLiteSegmentTreap);
begin
  if aTreap.FRoot <> nil then
    aTreap.FRoot := CopyTree(aTreap.FRoot);
end;

class procedure TGLiteSegmentTreap.Split(constref aKey: TKey; var aTreap: TGLiteSegmentTreap; out L,
  R: TGLiteSegmentTreap);
begin
  if aTreap.FRoot = nil then
    exit;
  SplitNode(aKey, aTreap.FRoot, L.FRoot, R.FRoot);
  aTreap.FRoot := nil;
end;

function TGLiteSegmentTreap.IsEmpty: Boolean;
begin
  Result := FRoot = nil;
end;

procedure TGLiteSegmentTreap.Clear;
begin
  if FRoot <> nil then
    TUtil.ClearTree(FRoot);
  FRoot := nil;
end;

function TGLiteSegmentTreap.ToArray: TEntryArray;
var
  a: TEntryArray = nil;
  I: Integer = 0;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.Left);
        a[I] := TEntry.Create(aNode^.Key, aNode^.Value);
        Inc(I);
        Visit(aNode^.Right);
      end;
  end;
begin
  if FRoot <> nil then
    begin
      System.SetLength(a, FRoot^.Size);
      Visit(FRoot);
    end;
  Result := a;
end;

function TGLiteSegmentTreap.Contains(constref aKey: TKey): Boolean;
begin
  Result := TUtil.FindKey(FRoot, aKey) <> nil;
end;

function TGLiteSegmentTreap.Find(constref aKey: TKey; out aValue: TValue): Boolean;
var
  Node: PNode;
begin
  if FRoot <> nil then
    begin
      Node := TUtil.FindKey(FRoot, aKey);
      if Node <> nil then
        begin
          aValue := Node^.Value;
          exit(True);
        end;
    end;
  Result := False;
end;

function TGLiteSegmentTreap.IndexOf(constref aKey: TKey): SizeInt;
begin
  Result := TUtil.GetKeyIndex(FRoot, aKey);
end;

function TGLiteSegmentTreap.Add(constref aKey: TKey; constref aValue: TValue): Boolean;
begin
  if FRoot <> nil then
    begin
      if Contains(aKey) then
        exit(False);
      AddNode(FRoot, NewNode(aKey, aValue));
    end
  else
    FRoot := NewNode(aKey, aValue);
  Result := True;
end;

function TGLiteSegmentTreap.Add(constref e: TEntry): Boolean;
begin
  Result := Add(e.Key, e.Value);
end;

function TGLiteSegmentTreap.Remove(constref aKey: TKey): Boolean;
begin
  if FRoot <> nil  then
    Result := RemoveNode(aKey, FRoot)
  else
    Result := False;
end;

function TGLiteSegmentTreap.Remove(constref aKey: TKey; out aValue: TValue): Boolean;
begin
  if FRoot <> nil  then
    Result := RemoveNode(aKey, FRoot, aValue)
  else
    Result := False;
end;

procedure TGLiteSegmentTreap.Split(constref aKey: TKey; out aTreap: TGLiteSegmentTreap);
begin
  if FRoot <> nil then
    SplitNode(aKey, FRoot, FRoot, aTreap.FRoot);
end;

function TGLiteSegmentTreap.RangeQueryI(L, R: SizeInt): TValue;
begin
  CheckIndexRange(L);
  CheckIndexRange(R);
  if L <= R then
    if R < Pred(FRoot^.Size) then
      exit(RangeQuery(TUtil.GetByIndex(FRoot, L)^.Key, TUtil.GetByIndex(FRoot, Succ(R))^.Key))
    else
      exit(TailQuery(TUtil.GetByIndex(FRoot, L)^.Key));
  Result := TValMonoid.Identity;
end;

function TGLiteSegmentTreap.RangeQuery(constref L, R: TKey): TValue;
var
  pL, pM, pR: PNode;
begin
  if (FRoot <> nil) and (TCmpRel.Compare(L, R) < 0) then
    begin
      SplitNode(L, FRoot, pL, pR);
      SplitNode(R, pR, pM, pR);
      if pM <> nil then
        Result := pM^.CacheVal
      else
        Result := TValMonoid.Identity;
      FRoot := MergeNode(MergeNode(pL, pM), pR);
    end
  else
    Result := TValMonoid.Identity;
end;

function TGLiteSegmentTreap.HeadQueryI(aIndex: SizeInt): TValue;
begin
  CheckIndexRange(aIndex);
  if aIndex < Pred(FRoot^.Size) then
    Result := HeadQuery(TUtil.GetByIndex(FRoot, Succ(aIndex))^.Key)
  else
    Result := FRoot^.CacheVal;
end;

function TGLiteSegmentTreap.HeadQuery(constref aKey: TKey): TValue;
var
  pL, pR: PNode;
begin
  if FRoot <> nil then
    begin
      SplitNode(aKey, FRoot, pL, pR);
      if pL <> nil then
        Result := pL^.CacheVal
      else
        Result := TValMonoid.Identity;
      FRoot := MergeNode(pL, pR);
    end
  else
    Result := TValMonoid.Identity;
end;

function TGLiteSegmentTreap.TailQueryI(aIndex: SizeInt): TValue;
begin
  CheckIndexRange(aIndex);
  Result := TailQuery(TUtil.GetByIndex(FRoot, aIndex)^.Key);
end;

function TGLiteSegmentTreap.TailQuery(constref aKey: TKey): TValue;
var
  pL, pR: PNode;
begin
  if FRoot <> nil then
    begin
      SplitNode(aKey, FRoot, pL, pR);
      if pR <> nil then
        Result := pR^.CacheVal
      else
        Result := TValMonoid.Identity;
      FRoot := MergeNode(pL, pR);
    end
  else
    Result := TValMonoid.Identity;
end;

{ TGLiteImplicitTreap }

function TGLiteImplicitTreap.GetCount: SizeInt;
begin
  Result := TUtil.GetNodeSize(FRoot);
end;

function TGLiteImplicitTreap.GetHeight: SizeInt;
begin
  Result := TUtil.GetHeight(FRoot);
end;

function TGLiteImplicitTreap.GetItem(aIndex: SizeInt): T;
begin
  CheckIndexRange(aIndex);
  Result := TUtil.GetByIndex(FRoot, aIndex)^.Value;
end;

procedure TGLiteImplicitTreap.SetItem(aIndex: SizeInt; const aValue: T);
begin
  CheckIndexRange(aIndex);
  TUtil.GetByIndex(FRoot, aIndex)^.Value := aValue;
end;

procedure TGLiteImplicitTreap.CheckIndexRange(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) >= SizeUInt(TUtil.GetNodeSize(FRoot)) then
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteImplicitTreap.CheckInsertRange(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) > SizeUInt(TUtil.GetNodeSize(FRoot)) then
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

class function TGLiteImplicitTreap.NewNode(constref aValue: T): PNode;
begin
  Result := System.GetMem(SizeOf(TNode));
  System.FillChar(Result^, SizeOf(TNode), 0);
  Result^.Prio := {$IFDEF CPU64}BJNextRandom64{$ELSE}BJNextRandom{$ENDIF};
  Result^.Size := 1;
  Result^.Value := aValue;
end;

class function TGLiteImplicitTreap.CopyTree(aRoot: PNode): PNode;
var
  Tmp: TGLiteImplicitTreap;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.Left);
        Tmp.Add(aNode^.Value);
        Visit(aNode^.Right);
      end;
  end;
begin
  if aRoot = nil then exit(nil);
  Tmp.Clear;
  Visit(aRoot);
  Result := Tmp.FRoot;
  Tmp.FRoot := nil;
end;

class procedure TGLiteImplicitTreap.UpdateSize(aNode: PNode);
begin
  with aNode^ do
    begin
      Size := 1;
      if Left <> nil then
        Size += Left^.Size;
      if Right <> nil then
        Size += Right^.Size;
    end;
end;

class procedure TGLiteImplicitTreap.SplitNode(aIdx: SizeInt; aRoot: PNode; out L, R: PNode);
var
  CurrIdx: SizeInt;
begin
  if aRoot <> nil then
    begin
      CurrIdx := TUtil.GetNodeSize(aRoot^.Left);
      if CurrIdx < aIdx then
        begin
          L := aRoot;
          SplitNode(aIdx - Succ(CurrIdx), L^.Right, L^.Right, R);
        end
      else
        begin
          R := aRoot;
          SplitNode(aIdx, R^.Left, L, R^.Left);
        end;
      UpdateSize(aRoot);
      exit;
    end;
  L := nil;
  R := nil;
end;

class function TGLiteImplicitTreap.MergeNode(L, R: PNode): PNode;
begin
  if L = nil then
    Result := R
  else
    if R = nil then
      Result := L
    else
      begin
        if L^.Prio > R^.Prio then
          begin
            L^.Right := MergeNode(L^.Right, R);
            Result := L;
          end
        else
          begin
            R^.Left := MergeNode(L, R^.Left);
            Result := R;
          end;
        UpdateSize(Result);
      end;
end;

class procedure TGLiteImplicitTreap.DeleteNode(aIndex: SizeInt; var aRoot: PNode; out aValue: T);
var
  LSize: SizeInt;
  Found: PNode;
begin
  if aRoot <> nil then
    begin
      LSize := TUtil.GetNodeSize(aRoot^.Left);
      if LSize = aIndex then
        begin
          Found := aRoot;
          aRoot := MergeNode(aRoot^.Left, aRoot^.Right);
          aValue := Found^.Value;
          TUtil.FreeNode(Found);
        end
      else
        begin
          if LSize > aIndex then
            DeleteNode(aIndex, aRoot^.Left, aValue)
          else
            DeleteNode(aIndex - Succ(LSize), aRoot^.Right, aValue);
          UpdateSize(aRoot);
        end;
    end;
end;

class operator TGLiteImplicitTreap.Initialize(var aTreap: TGLiteImplicitTreap);
begin
  aTreap.FRoot := nil;
end;

class operator TGLiteImplicitTreap.Finalize(var aTreap: TGLiteImplicitTreap);
begin
  aTreap.Clear;
end;

class operator TGLiteImplicitTreap.Copy(constref aSrc: TGLiteImplicitTreap; var aDst: TGLiteImplicitTreap);
begin
  aDst.Clear;
  if aSrc.FRoot <> nil then
    aDst.FRoot := CopyTree(aSrc.FRoot);
end;

class operator TGLiteImplicitTreap.AddRef(var aTreap: TGLiteImplicitTreap);
begin
  if aTreap.FRoot <> nil then
    aTreap.FRoot := CopyTree(aTreap.FRoot);
end;

class procedure TGLiteImplicitTreap.Split(aIndex: SizeInt; var aTreap: TGLiteImplicitTreap;
  out L, R: TGLiteImplicitTreap);
begin
  aTreap.CheckIndexRange(aIndex);
  SplitNode(aIndex, aTreap.FRoot, L.FRoot, R.FRoot);
  aTreap.FRoot := nil;
end;

function TGLiteImplicitTreap.IsEmpty: Boolean;
begin
  Result := FRoot = nil;
end;

procedure TGLiteImplicitTreap.Clear;
begin
  if FRoot <> nil then
    TUtil.ClearTree(FRoot);
  FRoot := nil;
end;

function TGLiteImplicitTreap.ToArray: TArray;
var
  a: TArray = nil;
  I: Integer = 0;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.Left);
        a[I] := aNode^.Value;
        Inc(I);
        Visit(aNode^.Right);
      end;
  end;
begin
  if FRoot = nil then exit(nil);
  System.SetLength(a, FRoot^.Size);
  Visit(FRoot);
  Result := a;
end;

function TGLiteImplicitTreap.Add(constref aValue: T): SizeInt;
begin
  Result := TUtil.GetNodeSize(FRoot);
  if FRoot <> nil then
    FRoot := MergeNode(FRoot, NewNode(aValue))
  else
    FRoot := NewNode(aValue);
end;

procedure TGLiteImplicitTreap.Insert(aIndex: SizeInt; constref aValue: T);
var
  L, R: PNode;
begin
  CheckInsertRange(aIndex);
  if FRoot <> nil then
    if aIndex > 0 then
      if aIndex < Pred(FRoot^.Size) then
        begin
          SplitNode(aIndex, FRoot, L, R);
          FRoot := MergeNode(MergeNode(L, NewNode(aValue)), R);
        end
      else
        FRoot := MergeNode(FRoot, NewNode(aValue))
    else
      FRoot := MergeNode(NewNode(aValue), FRoot)
  else
    FRoot := NewNode(aValue);
end;

procedure TGLiteImplicitTreap.Insert(aIndex: SizeInt; var aTreap: TGLiteImplicitTreap);
var
  L, R: PNode;
begin
  CheckInsertRange(aIndex);
  if aTreap.FRoot = nil then
    exit;
  if FRoot <> nil then
    if aIndex > 0 then
      if aIndex < Pred(FRoot^.Size) then
        begin
          SplitNode(aIndex, FRoot, L, R);
          FRoot := MergeNode(MergeNode(L, aTreap.FRoot), R);
        end
      else
        FRoot := MergeNode(FRoot, aTreap.FRoot)
    else
      FRoot := MergeNode(aTreap.FRoot, FRoot)
  else
    FRoot := aTreap.FRoot;
  aTreap.FRoot := nil;
end;

function TGLiteImplicitTreap.Delete(aIndex: SizeInt): T;
begin
  CheckIndexRange(aIndex);
  DeleteNode(aIndex, FRoot, Result);
end;

procedure TGLiteImplicitTreap.Split(aIndex: SizeInt; out aTreap: TGLiteImplicitTreap);
begin
  CheckIndexRange(aIndex);
  SplitNode(aIndex, FRoot, FRoot, aTreap.FRoot);
end;

procedure TGLiteImplicitTreap.Split(aIndex, aCount: SizeInt; out aTreap: TGLiteImplicitTreap);
var
  L, R: PNode;
begin
  CheckIndexRange(aIndex);
  if aCount < 1 then
    exit;
  aCount := Math.Min(aCount, FRoot^.Size - aIndex);
  if aCount < FRoot^.Size then
    begin
      SplitNode(aIndex, FRoot, L, R);
      SplitNode(aCount, R, aTreap.FRoot, R);
      FRoot := MergeNode(L, R);
    end
  else
    begin
      aTreap.FRoot := FRoot;
      FRoot := nil;
    end;
end;

procedure TGLiteImplicitTreap.Merge(var aTreap: TGLiteImplicitTreap);
begin
  FRoot := MergeNode(FRoot, aTreap.FRoot);
  aTreap.FRoot := nil;
end;

procedure TGLiteImplicitTreap.RotateLeft(aDist: SizeInt);
var
  L, R: PNode;
  cnt: SizeInt;
begin
  if FRoot = nil then exit;
  cnt := FRoot^.Size;
  if (aDist = 0) or (Abs(aDist) >= cnt) then
    exit;
  if aDist < 0 then
    aDist += cnt;
  SplitNode(aDist, FRoot, L, R);
  FRoot := MergeNode(R, L);
end;

procedure TGLiteImplicitTreap.RotateRight(aDist: SizeInt);
var
  L, R: PNode;
  cnt: SizeInt;
begin
  if FRoot = nil then exit;
  cnt := FRoot^.Size;
  if (aDist = 0) or (Abs(aDist) >= cnt) then
    exit;
  if aDist < 0 then
    aDist += cnt;
  SplitNode(cnt - aDist, FRoot, L, R);
  FRoot := MergeNode(R, L);
end;

{ TGLiteImplSegmentTreap }

function TGLiteImplSegmentTreap.GetCount: SizeInt;
begin
  Result := TUtil.GetNodeSize(FRoot);
end;

function TGLiteImplSegmentTreap.GetHeight: SizeInt;
begin
  Result := TUtil.GetHeight(FRoot);
end;

function TGLiteImplSegmentTreap.GetItem(aIndex: SizeInt): T;
begin
  CheckIndexRange(aIndex);
  Result := TUtil.GetByIndex(FRoot, aIndex)^.Value;
end;

procedure TGLiteImplSegmentTreap.SetItem(aIndex: SizeInt; const aValue: T);
begin
  CheckIndexRange(aIndex);
  UpdateValue(aIndex, FRoot, aValue);
end;

procedure TGLiteImplSegmentTreap.CheckIndexRange(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) >= SizeUInt(TUtil.GetNodeSize(FRoot)) then
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteImplSegmentTreap.CheckInsertRange(aIndex: SizeInt);
begin
  if SizeUInt(aIndex) > SizeUInt(TUtil.GetNodeSize(FRoot)) then
    raise EArgumentOutOfRangeException.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

class function TGLiteImplSegmentTreap.NewNode(constref aValue: T): PNode;
begin
  Result := System.GetMem(SizeOf(TNode));
  System.FillChar(Result^, SizeOf(TNode), 0);
  Result^.Prio := {$IFDEF CPU64}BJNextRandom64{$ELSE}BJNextRandom{$ENDIF};
  Result^.Size := 1;
  Result^.CacheVal := aValue;
  Result^.Value := aValue;
end;

class function TGLiteImplSegmentTreap.CopyTree(aRoot: PNode): PNode;
var
  Tmp: TGLiteImplSegmentTreap;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.Left);
        Tmp.Add(aNode^.Value);
        Visit(aNode^.Right);
      end;
  end;
begin
  Tmp.Clear;
  if aRoot <> nil then
    begin
      Visit(aRoot);
      Result := Tmp.FRoot;
      Tmp.FRoot := nil;
    end
  else
    Result := nil;
end;

class procedure TGLiteImplSegmentTreap.UpdateNode(aNode: PNode);
begin
  with aNode^ do
    begin
      Size := 1;
      CacheVal := aNode^.Value;
      if Left <> nil then
        begin
          Size += Left^.Size;
          CacheVal := TMonoid.BinOp(CacheVal, Left^.CacheVal);
        end;
      if Right <> nil then
        begin
          Size += Right^.Size;
          CacheVal := TMonoid.BinOp(CacheVal, Right^.CacheVal);
        end;
    end;
end;

class procedure TGLiteImplSegmentTreap.UpdateCache(aNode: PNode);
begin
  with aNode^ do
    begin
      CacheVal := aNode^.Value;
      if Left <> nil then
        CacheVal := TMonoid.BinOp(CacheVal, Left^.CacheVal);
      if Right <> nil then
        CacheVal := TMonoid.BinOp(CacheVal, Right^.CacheVal);
    end;
end;

class procedure TGLiteImplSegmentTreap.UpdateValue(aIndex: SizeInt; aRoot: PNode; constref aValue: T);
var
  LSize: SizeInt;
begin
  if aRoot <> nil then
    begin
      LSize := TUtil.GetNodeSize(aRoot^.Left);
      if LSize = aIndex then
        aRoot^.Value := aValue
      else
        if LSize > aIndex then
          UpdateValue(aIndex, aRoot^.Left, aValue)
        else
          UpdateValue(aIndex - Succ(LSize), aRoot^.Right, aValue);
      UpdateCache(aRoot);
    end;
end;

class procedure TGLiteImplSegmentTreap.SplitNode(aIdx: SizeInt; aRoot: PNode; out L, R: PNode);
var
  CurrIdx: SizeInt;
begin
  if aRoot <> nil then
    begin
      CurrIdx := TUtil.GetNodeSize(aRoot^.Left);
      if CurrIdx < aIdx then
        begin
          L := aRoot;
          SplitNode(aIdx - Succ(CurrIdx), L^.Right, L^.Right, R);
        end
      else
        begin
          R := aRoot;
          SplitNode(aIdx, R^.Left, L, R^.Left);
        end;
      UpdateNode(aRoot);
    end
  else
    begin
      L := nil;
      R := nil;
    end;
end;

class function TGLiteImplSegmentTreap.MergeNode(L, R: PNode): PNode;
begin
  if L = nil then
    Result := R
  else
    if R = nil then
      Result := L
    else
      begin
        if L^.Prio > R^.Prio then
          begin
            L^.Right := MergeNode(L^.Right, R);
            Result := L;
          end
        else
          begin
            R^.Left := MergeNode(L, R^.Left);
            Result := R;
          end;
        UpdateNode(Result);
      end;
end;

class procedure TGLiteImplSegmentTreap.DeleteNode(aIndex: SizeInt; var aRoot: PNode; out aValue: T);
var
  LSize: SizeInt;
  Found: PNode;
begin
  if aRoot <> nil then
    begin
      LSize := TUtil.GetNodeSize(aRoot^.Left);
      if LSize = aIndex then
        begin
          Found := aRoot;
          aRoot := MergeNode(aRoot^.Left, aRoot^.Right);
          aValue := Found^.Value;
          TUtil.FreeNode(Found);
        end
      else
        begin
          if LSize > aIndex then
            DeleteNode(aIndex, aRoot^.Left, aValue)
          else
            DeleteNode(aIndex - Succ(LSize), aRoot^.Right, aValue);
          UpdateNode(aRoot);
        end;
    end;
end;

class operator TGLiteImplSegmentTreap.Initialize(var aTreap: TGLiteImplSegmentTreap);
begin
  aTreap.FRoot := nil;
end;

class operator TGLiteImplSegmentTreap.Finalize(var aTreap: TGLiteImplSegmentTreap);
begin
  aTreap.Clear;
end;

class operator TGLiteImplSegmentTreap.Copy(constref aSrc: TGLiteImplSegmentTreap; var aDst: TGLiteImplSegmentTreap);
begin
  aDst.Clear;
  if aSrc.FRoot <> nil then
    aDst.FRoot := CopyTree(aSrc.FRoot);
end;

class operator TGLiteImplSegmentTreap.AddRef(var aTreap: TGLiteImplSegmentTreap);
begin
  if aTreap.FRoot <> nil then
    aTreap.FRoot := CopyTree(aTreap.FRoot);
end;

class procedure TGLiteImplSegmentTreap.Split(aIndex: SizeInt; var aTreap: TGLiteImplSegmentTreap;
  out L, R: TGLiteImplSegmentTreap);
begin
  aTreap.CheckIndexRange(aIndex);
  SplitNode(aIndex, aTreap.FRoot, L.FRoot, R.FRoot);
  aTreap.FRoot := nil;
end;

function TGLiteImplSegmentTreap.IsEmpty: Boolean;
begin
  Result := FRoot = nil;
end;

procedure TGLiteImplSegmentTreap.Clear;
begin
  if FRoot <> nil then
    TUtil.ClearTree(FRoot);
  FRoot := nil;
end;

function TGLiteImplSegmentTreap.ToArray: TArray;
var
  a: TArray = nil;
  I: Integer = 0;
  procedure Visit(aNode: PNode);
  begin
    if aNode <> nil then
      begin
        Visit(aNode^.Left);
        a[I] := aNode^.Value;
        Inc(I);
        Visit(aNode^.Right);
      end;
  end;
begin
  if FRoot <> nil then
    begin
      System.SetLength(a, FRoot^.Size);
      Visit(FRoot);
    end;
  Result := a;
end;

function TGLiteImplSegmentTreap.Add(constref aValue: T): SizeInt;
begin
  Result := TUtil.GetNodeSize(FRoot);
  if FRoot <> nil then
    FRoot := MergeNode(FRoot, NewNode(aValue))
  else
    FRoot := NewNode(aValue);
end;

procedure TGLiteImplSegmentTreap.Insert(aIndex: SizeInt; constref aValue: T);
var
  L, R: PNode;
begin
  CheckInsertRange(aIndex);
  if FRoot <> nil then
    if aIndex > 0 then
      if aIndex < Pred(FRoot^.Size) then
        begin
          SplitNode(aIndex, FRoot, L, R);
          FRoot := MergeNode(MergeNode(L, NewNode(aValue)), R);
        end
      else
        FRoot := MergeNode(FRoot, NewNode(aValue))
    else
      FRoot := MergeNode(NewNode(aValue), FRoot)
  else
    FRoot := NewNode(aValue);
end;

procedure TGLiteImplSegmentTreap.Insert(aIndex: SizeInt; var aTreap: TGLiteImplSegmentTreap);
var
  L, R: PNode;
begin
  CheckInsertRange(aIndex);
  if aTreap.FRoot = nil then
    exit;
  if FRoot <> nil then
    if aIndex > 0 then
      if aIndex < Pred(FRoot^.Size) then
        begin
          SplitNode(aIndex, FRoot, L, R);
          FRoot := MergeNode(MergeNode(L, aTreap.FRoot), R);
        end
      else
        FRoot := MergeNode(FRoot, aTreap.FRoot)
    else
      FRoot := MergeNode(aTreap.FRoot, FRoot)
  else
    FRoot := aTreap.FRoot;
  aTreap.FRoot := nil;
end;

function TGLiteImplSegmentTreap.Delete(aIndex: SizeInt): T;
begin
  CheckIndexRange(aIndex);
  DeleteNode(aIndex, FRoot, Result);
end;

procedure TGLiteImplSegmentTreap.Split(aIndex: SizeInt; out aTreap: TGLiteImplSegmentTreap);
begin
  CheckIndexRange(aIndex);
  SplitNode(aIndex, FRoot, FRoot, aTreap.FRoot);
end;

procedure TGLiteImplSegmentTreap.Split(aIndex, aCount: SizeInt; out aTreap: TGLiteImplSegmentTreap);
var
  L, R: PNode;
begin
  CheckIndexRange(aIndex);
  if aCount < 1 then
    exit;
  aCount := Math.Min(aCount, FRoot^.Size - aIndex);
  if aCount < FRoot^.Size then
    begin
      SplitNode(aIndex, FRoot, L, R);
      SplitNode(aCount, R, aTreap.FRoot, R);
      FRoot := MergeNode(L, R);
    end
  else
    begin
      aTreap.FRoot := FRoot;
      FRoot := nil;
    end;
end;

procedure TGLiteImplSegmentTreap.Merge(var aTreap: TGLiteImplSegmentTreap);
begin
  FRoot := MergeNode(FRoot, aTreap.FRoot);
  aTreap.FRoot := nil;
end;

procedure TGLiteImplSegmentTreap.RotateLeft(aDist: SizeInt);
var
  L, R: PNode;
  cnt: SizeInt;
begin
  if FRoot = nil then
    exit;
  cnt := FRoot^.Size;
  if (aDist = 0) or (Abs(aDist) >= cnt) then
    exit;
  if aDist < 0 then
    aDist += cnt;
  SplitNode(aDist, FRoot, L, R);
  FRoot := MergeNode(R, L);
end;

procedure TGLiteImplSegmentTreap.RotateRight(aDist: SizeInt);
var
  L, R: PNode;
  cnt: SizeInt;
begin
  if FRoot = nil then
    exit;
  cnt := FRoot^.Size;
  if (aDist = 0) or (Abs(aDist) >= cnt) then
    exit;
  if aDist < 0 then
    aDist += cnt;
  SplitNode(cnt - aDist, FRoot, L, R);
  FRoot := MergeNode(R, L);
end;

function TGLiteImplSegmentTreap.RangeQuery(L, R: SizeInt): T;
var
  pL, pM, pR: PNode;
begin
  CheckIndexRange(L);
  CheckIndexRange(R);
  if L <= R then
    if R < Pred(FRoot^.Size) then
      begin
        SplitNode(L, FRoot, pL, pR);
        SplitNode(Succ(R) - L, pR, pM, pR);
        if pM <> nil then
           Result := pM^.CacheVal
        else
          Result := TMonoid.Identity;
        FRoot := MergeNode(MergeNode(pL, pM), pR);
      end
    else
       Result := TailQuery(L)
  else
    Result := TMonoid.Identity;
end;

function TGLiteImplSegmentTreap.HeadQuery(aIndex: SizeInt): T;
var
  pL, pR: PNode;
begin
  CheckIndexRange(aIndex);
  if aIndex < Pred(FRoot^.Size) then
    begin
      SplitNode(Succ(aIndex), FRoot, pL, pR);
      if pL <> nil then
        Result := pL^.CacheVal
      else
        Result := TMonoid.Identity;
      FRoot := MergeNode(pL, pR);
    end
  else
    Result := FRoot^.CacheVal;
end;

function TGLiteImplSegmentTreap.TailQuery(aIndex: SizeInt): T;
var
  pL, pR: PNode;
begin
  CheckIndexRange(aIndex);
  if aIndex > 0 then
    begin
      SplitNode(aIndex, FRoot, pL, pR);
      if pR <> nil then
        Result := pR^.CacheVal
      else
        Result := TMonoid.Identity;
      FRoot := MergeNode(pL, pR);
    end
  else
    Result := FRoot^.CacheVal;
end;

end.
