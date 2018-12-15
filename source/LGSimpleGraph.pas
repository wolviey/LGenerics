{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic simple undirected graphs implementation.                        *
*                                                                           *
*   Copyright(c) 2018 A.Koverdyaev(avk)                                     *
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
unit LGSimpleGraph;

{$mode objfpc}{$H+}
{$INLINE ON}{$WARN 6058 off : }
{$WARN 5024 off : Parameter "$1" not used}
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH NESTEDPROCVARS}

interface

uses
  Classes, SysUtils, DateUtils,
  LGMvMatch,
  LGUtils,
  {%H-}LGHelpers,
  LGArrayHelpers,
  LGVector,
  LGQueue,
  LGSparseGraph,
  LGStrHelpers,
  LGMiscUtils,
  LGStrConst;

type
  TLineGraph = class; //forward declaration

  { TGSimpleGraph implements simple sparse undirected graph based on adjacency lists;
      functor TEqRel must provide:
        class function HashCode([const[ref]] aValue: TVertex): SizeInt;
        class function Equal([const[ref]] L, R: TVertex): Boolean; }
  generic TGSimpleGraph<TVertex, TEdgeData, TEqRel> = class(specialize TGSparseGraph<TVertex, TEdgeData, TEqRel>)
  protected
  type
    TSortByDegreeHelper = specialize TGDelegatedArrayHelper<SizeInt>;

    {$I SimpGraphHelpH.inc}

    TDistinctEdgeEnumerator = record
    private
      FList: PNode;
      FEnum: TAdjList.TEnumerator;
      FCurrIndex,
      FLastIndex: SizeInt;
      FEnumDone: Boolean;
      function  GetCurrent: TEdge;
    public
      function  MoveNext: Boolean;
      procedure Reset;
      property  Current: TEdge read GetCurrent;
    end;

    TDistinctEdges = record
      private
        FGraph: TGSimpleGraph;
      public
        function GetEnumerator: TDistinctEdgeEnumerator;
    end;

  const
    LISTCLIQUES_BP_CUTOFF       = 60000; //BP: bit-parallel
    COMMON_BP_CUTOFF            = 50000;
    MAXCLIQUE_BP_DENSITY_CUTOFF = 0.005;

  protected
    FCompCount: SizeInt;
    FConnected,
    FConnectedValid: Boolean;
    procedure ResetTags;
    function  SeparateTag(aIndex: SizeInt): SizeInt;
    function  SeparateJoin(L, R: SizeInt): Boolean;
    procedure ValidateConnected;
    function  GetConnected: Boolean; inline;
    function  GetDensity: Double; inline;
    procedure DoRemoveVertex(aIndex: SizeInt);
    function  DoAddEdge(aSrc, aDst: SizeInt; aData: TEdgeData): Boolean;
    function  DoRemoveEdge(aSrc, aDst: SizeInt): Boolean;
    function  CreateSkeleton: TSkeleton;
    procedure AssignGraph(aGraph: TGSimpleGraph);
    procedure AssignSeparate(aGraph: TGSimpleGraph; aIndex: SizeInt);
    procedure AssignVertexList(aGraph: TGSimpleGraph; const aList: TIntArray);
    procedure AssignTree(aGraph: TGSimpleGraph; const aTree: TIntArray);
    procedure AssignEdges(aGraph: TGSimpleGraph; const aEdges: TIntEdgeArray);
    function  GetSeparateGraph(aIndex: SizeInt): TGSimpleGraph;
    function  GetSeparateCount: SizeInt;
    function  CountPop(aTag: SizeInt): SizeInt;
    function  MakeConnected(aOnAddEdge: TOnAddEdge): SizeInt;
    function  CycleExists(aRoot: SizeInt; out aCycle: TIntArray): Boolean;
    function  GetMaxCliqueBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMaxCliqueBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMaxClique(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GreedyMatching: TIntEdgeArray;
    function  GreedyMatching2: TIntEdgeArray;
    function  GetMvMatching: TIntEdgeArray;
    procedure ListCliquesBP(aOnFind: TOnFindSet);
    procedure ListCliquesBP256(aOnFind: TOnFindSet);
    procedure ListCliques(aOnFind: TOnFindSet);
  { returns max independent set in bipartite graph }
    function  GetMaxIsBipartite(const w, g: TIntArray): TIntArray;
    function  GetMaxIsBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMaxIsBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    procedure ListIsBP(aOnFind: TOnFindSet);
    procedure ListIsBP256(aOnFind: TOnFindSet);
    function  GetGreedyMis: TIntArray;
    function  GetGreedyMisBP: TIntArray;
    function  GetGreedyMinIs: TIntArray;
    function  GetGreedyMinIsBP: TIntArray;
    function  GetMdsBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMdsBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMds(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  ColorTrivial(out aMaxColor: SizeInt; out aColors: TIntArray): Boolean;
    function  ColorConnected(aTimeOut: Integer; out aColors: TIntArray; out aExact: Boolean): SizeInt;
    function  ColorDisconnected(aTimeOut: Integer; out aColors: TIntArray; out aExact: Boolean): SizeInt;
    function  ColorableConnected(aK: SizeInt; aTimeOut: Integer; out aColors: TIntArray): TTriLean;
    function  ColorableDisconnected(aK: SizeInt; aTimeOut: Integer; out aColors: TIntArray): TTriLean;
    function  GreedyColorRlf(out aColors: TIntArray): SizeInt;
    function  GreedyColor(out aColors: TIntArray): SizeInt;
    procedure SearchForCutVertices(aRoot: SizeInt; var aPoints: TIntHashSet);
    function  CutVertexExists(aRoot: SizeInt): Boolean;
    procedure SearchForBiconnect(aRoot: SizeInt; var aEdges: TIntEdgeVector);
    procedure SearchForBicomponent(aRoot: SizeInt; var aComp: TEdgeArrayVector);
    function  BridgeExists: Boolean;
    procedure SearchForBridges(var aBridges: TIntEdgeVector);
    procedure SearchForFundamentalsCycles(out aCycles: TIntArrayVector);
    procedure SearchForFundamentalsCyclesLen(out aCycleLens: TIntVector);
    procedure FindFundamentalCyclesLen(out aCycleLens: TIntVector);
    function  CreateDegreeArray: TIntArray;
    function  CreateComplementDegreeArray: TIntArray;
    function  SortNodesByWidth(o: TSortOrder): TIntArray;
    function  SortComplementByWidth: TIntArray;
    function  SortNodesByDegree(o: TSortOrder): TIntArray;
    function  CmpByDegree(constref L, R: SizeInt): SizeInt;
    function  CmpIntArrayLen(constref L, R: TIntArray): SizeInt;
  public
{**********************************************************************************************************
  auxiliary utilities
***********************************************************************************************************}
    class function MayBeEqual(L, R: TGSimpleGraph): Boolean;
{**********************************************************************************************************
  class management utilities
***********************************************************************************************************}
    constructor Create;
    procedure Clear; override;
  { saves graph in its own binary format }
    procedure SaveToStream(aStream: TStream);
    procedure LoadFromStream(aStream: TStream);
    procedure SaveToFile(const aFileName: string);
    procedure LoadFromFile(const aFileName: string);
  { returns copy of the source graph }
    function  Clone: TGSimpleGraph;
  { returns graph of connected component that contains aVertex }
    function  SeparateGraph(constref aVertex: TVertex): TGSimpleGraph;
    function  SeparateGraphI(aIndex: SizeInt): TGSimpleGraph;
  { returns a subgraph induced by the vertices whose indices are contained in the array aList }
    function  SubgraphFromVertexList(const aList: TIntArray): TGSimpleGraph;
  { returns a gsubgraph induced the pairs provided by the aTree,
    i.e. each element treates as pair of source - destination(value -> source, index -> destination ) }
    function  SubgraphFromTree(const aTree: TIntArray): TGSimpleGraph;
  { returns a graph constructed from the edges provided by the aEdges }
    function  SubgraphFromEdges(const aEdges: TIntEdgeArray): TGSimpleGraph;
  { returns line graph constucted from self }
    function  CreateLineGraph: TLineGraph;
{**********************************************************************************************************
  structural management utilities
***********************************************************************************************************}

  { returns True and vertex index, if it is added, False if such a vertex already exists }
    function  AddVertex(constref aVertex: TVertex; out aIndex: SizeInt): Boolean;
    function  AddVertex(constref aVertex: TVertex): Boolean; inline;
  { returns count of added vertices }
    function  AddVertices(const aVertices: TVertexArray): SizeInt;
  { raises EGraphError if graph not contains aVertex }
    procedure RemoveVertex(constref aVertex: TVertex); inline;
    procedure RemoveVertexI(aIndex: SizeInt);
  { returns True if the edge is added, False, if such an edge already exists }
    function  AddEdge(constref aSrc, aDst: TVertex; aData: TEdgeData): Boolean;
    function  AddEdge(constref aSrc, aDst: TVertex): Boolean; inline;
    function  AddEdgeI(aSrc, aDst: SizeInt; aData: TEdgeData): Boolean;
    function  AddEdgeI(aSrc, aDst: SizeInt): Boolean; inline;
  { returns False if there is no such edge; edge removing breaks validity of connected property }
    function  RemoveEdge(constref aSrc, aDst: TVertex): Boolean; inline;
    function  RemoveEdgeI(aSrc, aDst: SizeInt): Boolean;
    function  Degree(constref aVertex: TVertex): SizeInt; inline;
    function  DegreeI(aIndex: SizeInt): SizeInt;
    function  Isolated(constref aVertex: TVertex): Boolean; inline;
    function  IsolatedI(aIndex: SizeInt): Boolean; inline;
    function  DistinctEdges: TDistinctEdges; inline;
  { returns adjacency matrix of the complement graph;
    warning: maximum matrix size limited, see MaxBitMatrixSize }
    function  ComplementMatrix: TAdjacencyMatrix;
  { returns local clustering coefficient of the aVertex: how close its neighbours are to being a clique }
    function  LocalClustering(constref aVertex: TVertex): ValReal; inline;
    function  LocalClusteringI(aIndex: SizeInt): Double;
  { if the graph is not empty, then make graph connected, adding, if necessary, new edges
    from the vertex with the index 0; returns count of added edges;
    if aOnAddEdge = nil then new edges will use default data value }
    function  EnsureConnected(aOnAddEdge: TOnAddEdge = nil): SizeInt;
  { checks whether the aDst reachable from the aSrc; each vertex reachable from itself  }
    function  PathExists(constref aSrc, aDst: TVertex): Boolean; inline;
    function  PathExistsI(aSrc, aDst: SizeInt): Boolean;
  { returns number of vertices(population) in the connected component that contains aVertex }
    function  SeparatePop(constref aVertex: TVertex): SizeInt; inline;
    function  SeparatePopI(aIndex: SizeInt): SizeInt;
  { returns array of indices of connected component that contains aVertex }
    function  GetSeparate(constref aVertex: TVertex): TIntArray; inline;
    function  GetSeparateI(aIndex: SizeInt): TIntArray;
  { returns in the result array the vectors of indices of all connected components }
    function  FindSeparates: TIntVectorArray;
    function  IsTree: Boolean; inline;
    function  IsStar(out aHub: SizeInt): Boolean;
    function  IsCycle: Boolean;
    function  IsWheel(out aHub: SizeInt): Boolean;
    function  IsComplete: Boolean; inline;
  { checks whether the graph is regular(that is, the degrees of all its vertices are equal);
    an empty graph is considered regular }
    function  IsRegular(out aDegree: SizeInt): Boolean;
    function  CyclomaticNumber: SizeInt; inline;
  { returns True if exists any cycle in the aVertex connected component,
    in this case aCycle will contain indices of the vertices of the found cycle }
    function  ContainsCycle(constref aVertex: TVertex; out aCycle: TIntArray): Boolean; inline;
    function  ContainsCycleI(aIndex: SizeInt; out aCycle: TIntArray): Boolean;
  { checks whether exists Eulerian path; if exists only path, then
    aFirstOdd will contains index of first vertex with odd degree, otherwise -1 }
    function  ContainsEulerianPath(out aFirstOdd: SizeInt): Boolean;
  { checks whether exists Eulerian cycle }
    function  ContainsEulerianCycle: Boolean;
  { looking for some Eulerian cycle in the connected component }
    function  FindEulerianCycle: TIntArray;
  { looking for some Eulerian path in the connected component }
    function  FindEulerianPath: TIntArray;
  { finds a certain system of fundamental cycles }
    function  FindFundamentalCycles: TIntArrayVector;
  { checks whether exists any articulation point that belong to the aVertex connected component }
    function  ContainsCutVertex(constref aVertex: TVertex): Boolean; inline;
    function  ContainsCutVertexI(aIndex: SizeInt): Boolean;
  { returns the articulation points that belong to the aVertex connection component, if any,
    otherwise the empty vector }
    function  FindCutVertices(constref aVertex: TVertex): TIntArray; inline;
    function  FindCutVerticesI(aIndex: SizeInt): TIntArray;
  { removes the articulation points that belong to the aVertex connected component, adding,
    if necessary, new edges; returns count of added edges;
    if aOnAddEdge is nil then new edges will use default data value }
    function  RemoveCutVertices(constref aVertex: TVertex; aOnAddEdge: TOnAddEdge = nil): SizeInt; inline;
    function  RemoveCutVerticesI(aIndex: SizeInt; aOnAddEdge: TOnAddEdge = nil): SizeInt;
  { checks whether exists any bridge in graph }
    function  ContainsBridge: Boolean;
  { returns all bridges in the result vector, if any, otherwise the empty vector }
    function  FindBridges: TIntEdgeArray;
  { checks whether the graph is biconnected; graph with single vertex is considered biconnected }
    function  IsBiconnected: Boolean; inline;
  { returns vector containing in the corresponding elements edges of found bicomponents
    in aVertex connected component }
    function  FindBicomponents(constref aVertex: TVertex): TEdgeArrayVector;
    function  FindBicomponentsI(aIndex: SizeInt): TEdgeArrayVector;
  { if the graph is not empty, then make graph biconnected, adding, if necessary, new edges;
    returns count of added edges; if aOnAddEdge is nil then new edges will use default data value }
    function  EnsureBiconnected(aOnAddEdge: TOnAddEdge): SizeInt;
  { returns True, radus and diameter, if graph is connected, False otherwise }
    function  FindMerics(out aRadius, aDiameter: SizeInt): Boolean;
  { returns True and indices of the central vertices in aCenter, if graph is connected, False otherwise }
    function  FindCenter(out aCenter: TIntArray): Boolean;

    type
      //vertex partition
      TCut = record
        A,
        B: TIntArray;
      end;

  { returns the some global minimum cut; used Nagamochi-Ibaraki algorithm }
    function  MinCut: SizeInt;
    function  MinCut(out aCut: TCut): SizeInt;
  { returns array of the edges that cross the minimum cut }
    function  MinCutCrossing: TIntEdgeArray;
{**********************************************************************************************************
  matching utilities
***********************************************************************************************************}

  { returns False if graph is not bipartite, otherwise in aMatch returns the matching of
    the maximum cardinality, used Hopcroft–Karp algorithm }
    function FindMaxBipartiteMatchingHK(out aMatch: TIntEdgeArray): Boolean;
  { returns the matching of the maximum cardinality in a bipartite graph without any checks }
    function MaxBipartiteMatchingHK(const aWhites, aGrays: TIntArray): TIntEdgeArray;
  { returns False if graph is not bipartite, otherwise in aMatch returns the matching of
    the maximum cardinality }
    function FindMaxBipartiteMatchingBfs(out aMatch: TIntEdgeArray): Boolean;
  { returns the matching of the maximum cardinality in a bipartite graph without any checks }
    function MaxBipartiteMatchingBfs(const aWhites, aGrays: TIntArray): TIntEdgeArray;
  { returns True if graph is bipartite and aMatch is maximal matching }
    function IsMaxBipartiteMatching(const aMatch: TIntEdgeArray): Boolean;
  { returns the approximation of the matching of the maximum cardinality in an arbitrary graph }
    function GreedyMaxMatching: TIntEdgeArray;
  { returns the matching of the maximum cardinality in an arbitrary graph;
    used Edmonds(?) algorithm }
    function FindMaxMatchingEd: TIntEdgeArray;
  { returns the matching of the maximum cardinality in an arbitrary graph;
    used Pape-Conradt algorithm }
    function FindMaxMatchingPC: TIntEdgeArray;
  { returns the matching of the maximum cardinality in an arbitrary graph;
    used Micali-Vazirani algorithm }
    function FindMaxMatchingMV: TIntEdgeArray;
{**********************************************************************************************************
  some NP-hard problem utilities
***********************************************************************************************************}

  { lists all maximal independent sets of vertices;
    will raise exception if aOnFindSet is not assigned;
    setting aCancel to True in aOnFindSet will result in an exit from the method }
    procedure ListIndependentSets(aOnFindSet: TOnFindSet);
  { returns indices of the vertices of the some found maximum independent set;
    worst case time cost of exact solution O*(3^n/3); aTimeOut specifies the timeout in seconds;
    at the end of the timeout the best recent solution will be returned, and aExactSolution
    will be set to False }
    function  MaxIndependentSet(out aExactSolution: Boolean; aTimeOut: Integer = WAIT_INFINITE): TIntArray;
    function  GreedyMIS: TIntArray;
  { returns True if aTestSet contains indices of the some maximal independent vertex set, False otherwise }
    function  IsMaxIndependentSet(const aTestSet: TIntArray): Boolean;
  { returns indices of the vertices of the some found minimum dominating set in connected graph;
    will raise exception if graph is disconnected;
    worst case time cost of exact solution O*(2^n);
    aTimeOut specifies the timeout in seconds; at the end of the timeout the best
    recent solution will be returned, and aExactSolution will be set to False }
    function  MinDominatingSet(out aExactSolution: Boolean; aTimeOut: Integer = WAIT_INFINITE): TIntArray;
    function  GreedyMDS: TIntArray;
  { returns True if aTestSet contains indices of the some minimal dominating vertex set, False otherwise }
    function  IsMinDominatingSet(const aTestSet: TIntArray): Boolean;
  { lists all maximal cliques;
    will raise exception if aOnFindClique is not assigned;
    setting aCancel to True in aOnFindClique will result in an exit from the method }
    procedure ListMaxCliques(aOnFindClique: TOnFindSet);
  { returns indices of the vertices of the some found maximum clique;
    worst case time cost of exact solution O*(3^n/3); aTimeOut specifies the timeout in seconds;
    at the end of the timeout the best recent solution will be returned, and aExactSolution
    will be set to False }
    function  MaxClique(out aExactSolution: Boolean; aTimeOut: Integer = WAIT_INFINITE): TIntArray;
    function  GreedyMaxClique: TIntArray;
  { returns True if aTestClique contains indices of the some maximal clique, False otherwise }
    function  IsMaxClique(const aTestClique: TIntArray): Boolean;
  { returns count of used colors(chromatic number, if aExact); returns colors of the vertices
    in corresponding components of aColors; worst case time cost of exact solution O*(k^n);
    aTimeOut specifies the timeout in seconds; at the end of the timeout,
    the best recent solution will be returned, and aExact will be set to False }
    function  VertexColoring(out aColors: TIntArray; out aExact: Boolean;
              aTimeOut: Integer = WAIT_INFINITE): SizeInt;
  { returns tlTrue if exist the vertex coloring which uses at most aK of colors;
    aTimeOut specifies the timeout in seconds; at the end of the timeout tlUnknown will be returned }
    function  IsKColorable(aK: SizeInt; out aColors: TIntArray; aTimeOut: Integer = WAIT_INFINITE): TTriLean;
  { returns True if it is possible to complete the coloring using colors no more than aMaxColor
    and using the predefined colors specified in aColors;
    aTimeOut specifies the timeout in seconds; at the end of the timeout False will be returned }
    function  FindCompleteColoring(aMaxColor: SizeInt; var aColors: TIntArray;
              aTimeOut: Integer = WAIT_INFINITE): Boolean;
  { returns count of colors; returns colors of the vertices in corresponding components of aColors;
    used RLF greedy coloring algorithm }
    function  GreedyVertexColoringRlf(out aColors: TIntArray): SizeInt;
  { returns count of colors; returns colors of the vertices in corresponding components of aColors(GIS ?) }
    function  GreedyVertexColoring(out aColors: TIntArray): SizeInt;
  { returns True if aTestColors is complete and proper coloring of the vertices, False otherwise }
    function  IsProperVertexColoring(const aTestColors: TIntArray): Boolean;
  { tries to return in aCycles the specified number of Hamiltonian cycles, starting from the vertex aSource;
    if aCount <= 0, then all cycles are returned; if aCount > 0, then
    Min(aCount, total) cycles are returned; aTimeOut specifies the timeout in seconds;
    at the end of the timeout False will be returned }
    function  FindHamiltonCycles(constref aSource: TVertex; aCount: SizeInt; out aCycles: TIntArrayVector;
              aTimeOut: Integer = WAIT_INFINITE): Boolean; inline;
    function  FindHamiltonCyclesI(aSourceIdx, aCount: SizeInt; out aCycles: TIntArrayVector;
              aTimeOut: Integer = WAIT_INFINITE): Boolean;
  { returns True if aTestCycle is Hamiltonian cycle starting from the vertex with index aSourceIdx }
    function  IsHamiltonCycle(const aTestCycle: TIntArray; aSourceIdx: SizeInt): Boolean;
  { tries to return in aPaths the specified number of Hamiltonian paths
    from the vertex aSrc to vertex aDst; if aCount <= 0, then all paths are returned;
    if aCount > 0, then Min(aCount, total) cycles are returned; aTimeOut specifies
    the timeout in seconds; at the end of the timeout False will be returned }
    function  FindHamiltonPaths(constref aSrc, aDst: TVertex; aCount: SizeInt; out aPaths: TIntArrayVector;
              aTimeOut: Integer = WAIT_INFINITE): Boolean; inline;
    function  FindHamiltonPathsI(aSrcIdx, aDstIdx, aCount: SizeInt; out aPaths: TIntArrayVector;
              aTimeOut: Integer = WAIT_INFINITE): Boolean;
  { returns True if aTestPath is Hamiltonian path starting from the vertex with index aSourceIdx }
    function  IsHamiltonPath(const aTestPath: TIntArray; aSrcIdx, aDstIdx: SizeInt): Boolean;
{**********************************************************************************************************
  properties
***********************************************************************************************************}

  { checks whether the cached info about connected is up-to-date }
    property  ConnectedValid: Boolean read FConnectedValid;
  { checks whether the graph is connected; an empty graph is considered disconnected }
    property  Connected: Boolean read GetConnected;
  { count of connected components }
    property  SeparateCount: SizeInt read GetSeparateCount;
    property  Density: Double read GetDensity;
  end;

  TLineGraph = class(specialize TGSimpleGraph<TOrdIntPair, TIntValue, TOrdIntPair>);

  { TGChart: simple outline;
      functor TEqRel must provide:
        class function HashCode([const[ref]] aValue: TVertex): SizeInt;
        class function Equal([const[ref]] L, R: TVertex): Boolean; }
  generic TGChart<TVertex, TEqRel> = class(specialize TGSimpleGraph<TVertex, TEmptyRec, TEqRel>)
  private
    procedure ReadData(aStream: TStream; out aValue: TEmptyRec);
    procedure WriteData(aStream: TStream; constref aValue: TEmptyRec);
  public
    constructor Create;
    function SeparateGraph(constref aVertex: TVertex): TGChart;
    function SeparateGraphI(aIndex: SizeInt): TGChart;
    function SubgraphFromVertexList(const aList: TIntArray): TGChart;
    function SubgraphFromTree(const aTree: TIntArray): TGChart;
    function SubgraphFromEdges(const aEdges: TIntEdgeArray): TGChart;
    function Clone: TGChart;
  end;

  TIntChart = class(specialize TGChart<Integer, Integer>)
  protected
    procedure WriteVertex(aStream: TStream; constref aValue: Integer);
    procedure ReadVertex(aStream: TStream; out aValue: Integer);
  public
    constructor Create;
    procedure LoadDIMACSAscii(const aFileName: string);
    function  SeparateGraph(aVertex: Integer): TIntChart;
    function  SeparateGraphI(aIndex: SizeInt): TIntChart;
    function  SubgraphFromVertexList(const aList: TIntArray): TIntChart;
    function  SubgraphFromTree(const aTree: TIntArray): TIntChart;
    function  SubgraphFromEdges(const aEdges: TIntEdgeArray): TIntChart;
    function  Clone: TIntChart;
  { adds numbers in range [aFrom, aTo] as vertices, returns count of added vertices }
    function  AddVertexRange(aFrom, aTo: Integer): Integer;
  { treats aVertexList as list of the pairs of source-target, odd element ignored;
    returns count of added edges; }
    function  AddEdges(const aVertexList: array of Integer): Integer;
  end;

  generic TGraphDotWriter<TVertex, TEdgeData, TEqRel> = class(
    specialize TGAbstractDotWriter<TVertex, TEdgeData, TEqRel>)
  protected
  type
    TSimpleGraph = specialize TGSimpleGraph<TVertex, TEdgeData, TEqRel>;

    function Graph2Dot(aGraph: TGraph): utf8string; override;
  public
    constructor Create;
  end;

  TIntChartDotWriter = class(specialize TGraphDotWriter<Integer, TEmptyRec, Integer>)
  protected
    function DefaultWriteEdge(aGraph: TGraph; constref aEdge: TGraph.TEdge): utf8string; override;
  end;

  { TStrChart
    warning: SaveToStream limitation for max string length = High(SmallInt) }
  TStrChart = class(specialize TGChart<string, string>)
  protected
    procedure WriteVertex(aStream: TStream; constref aValue: string);
    procedure ReadVertex(aStream: TStream; out aValue: string);
  public
    constructor Create;
    function SeparateGraph(const aVertex: string): TStrChart;
    function SeparateGraphI(aIndex: SizeInt): TStrChart;
    function SubgraphFromVertexList(const aList: TIntArray): TStrChart;
    function SubgraphFromTree(const aTree: TIntArray): TStrChart;
    function SubgraphFromEdges(const aEdges: TIntEdgeArray): TStrChart;
    function Clone: TStrChart;
  end;

  TStrChartDotWriter = class(specialize TGraphDotWriter<string, TEmptyRec, string>)
  protected
    function DefaultWriteEdge(aGraph: TGraph; constref aEdge: TGraph.TEdge): utf8string; override;
  end;

  { TGWeightedGraph implements simple sparse undirected weighed graph based on adjacency lists;
      functor TEqRel must provide:
        class function HashCode([const[ref]] aValue: TVertex): SizeInt;
        class function Equal([const[ref]] L, R: TVertex): Boolean;

      TEdgeData must provide field/property/function Weight: TWeight;

      TWeight must be one of predefined signed numeric types;
      properties MinValue, MaxValue used as infinity weight values }
  generic TGWeightedGraph<TVertex, TWeight, TEdgeData, TEqRel> = class(
    specialize TGSimpleGraph<TVertex, TEdgeData, TEqRel>)
  private
  type
    TWeightHelper = specialize TGWeightHelper<TVertex, TWeight, TEdgeData, TEqRel>;

  public
  type
    TWeightArray  = TWeightHelper.TWeightArray;
    TWeightEdge   = TWeightHelper.TWeightEdge;
    TEdgeArray    = array of TWeightEdge;
    TEstimate     = TWeightHelper.TEstimate;
    TWeightMatrix = TWeightHelper.TWeightMatrix;
    TApspCell     = TWeightHelper.TApspCell;
    TApspMatrix   = TWeightHelper.TApspMatrix;

  protected
  type
    TPairingHeap = TWeightHelper.TPairHeap;
    TWeightItem  = TWeightHelper.TWeightItem;
    TEdgeHelper  = specialize TGComparableArrayHelper<TWeightEdge>;
    TPairHeapMax = specialize TGPairHeapMax<TWeightItem>;

    function CreateEdgeArray: TEdgeArray;
  public
{**********************************************************************************************************
  auxiliary utilities
***********************************************************************************************************}
    class function InfWeight: TWeight; static; inline;
    class function NegInfWeight: TWeight; static; inline;
    class function TotalWeight(const aEdges: TEdgeArray): TWeight; static;
  { returns True if exists edge with negative weight }
    function ContainsNegWeightEdge: Boolean;
  { checks whether exists any negative weight cycle in connected component that
    contains a aRoot; if True then aCycle will contain indices of the vertices of the cycle }
    function ContainsNegCycle(constref aRoot: TVertex; out aCycle: TIntArray): Boolean; inline;
    function ContainsNegCycleI(aRootIdx: SizeInt; out aCycle: TIntArray): Boolean;
{**********************************************************************************************************
  class management utilities
***********************************************************************************************************}
    function SeparateGraph(constref aVertex: TVertex): TGWeightedGraph;
    function SeparateGraphI(aIndex: SizeInt): TGWeightedGraph;
    function SubgraphFromVertexList(const aList: TIntArray): TGWeightedGraph;
    function SubgraphFromTree(const aTree: TIntArray): TGWeightedGraph;
    function SubgraphFromEdges(const aEdges: TIntEdgeArray): TGWeightedGraph;
    function Clone: TGWeightedGraph;
{**********************************************************************************************************
  shortest path problem utilities
***********************************************************************************************************}

  { finds all paths of minimal weight from a given vertex to the remaining vertices in the same
    connected component(SSSP), the weights of all edges must be nonnegative;
    the result contains in the corresponding component the weight of the path to the vertex or
    InfWeight if the vertex is unreachable; used Dijkstra's algorithm  }
    function MinPathsMap(constref aSrc: TVertex): TWeightArray; inline;
    function MinPathsMapI(aSrc: SizeInt): TWeightArray;
  { same as above and in aPathTree returns paths }
    function MinPathsMap(constref aSrc: TVertex; out aPathTree: TIntArray): TWeightArray; inline;
    function MinPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray): TWeightArray;
  { returns False if exists negative weight cycle reachable from aSrc,
    otherwise finds all paths of minimal weight from a given vertex to the remaining
    vertices in the same connected component(SSSP); an aWeights will contain
    in the corresponding component the weight of the path to the vertex or InfWeight
    if the vertex is unreachable; used BFMT algorithm  }
    function FindMinPathsMap(constref aSrc: TVertex; out aWeights: TWeightArray): Boolean; inline;
    function FindMinPathsMapI(aSrc: SizeInt; out aWeights: TWeightArray): Boolean;
  { same as above and in aPathTree returns paths }
    function FindMinPathsMap(constref aSrc: TVertex; out aPathTree: TIntArray; out aWeights: TWeightArray): Boolean; inline;
    function FindMinPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray; out aWeights: TWeightArray): Boolean;
  { finds the path of minimal weight from a aSrc to aDst if it exists(pathfinding);
    the weights of all edges must be nonnegative;
    returns weight of the path or InfWeight if the vertex is unreachable; used Dijkstra's algorithm  }
    function MinPathWeight(constref aSrc, aDst: TVertex): TWeight; inline;
    function MinPathWeightI(aSrc, aDst: SizeInt): TWeight;
  { returns the vertex path of minimal weight from a aSrc to aDst, if exists, and its weight in aWeight }
    function MinPath(constref aSrc, aDst: TVertex; out aWeight: TWeight): TIntArray; inline;
    function MinPathI(aSrc, aDst: SizeInt; out aWeight: TWeight): TIntArray;
  { returns False if exists negative weight cycle reachable from aSrc,
    otherwise returns the vertex path of minimal weight from a aSrc to aDst in aPath,
    if exists, and its weight in aWeight;
    to distinguish 'unreachable' and 'negative cycle': in case negative cycle aWeight returns ZeroWeight,
    but InfWeight if aDst unreachable; used BFMT algorithm }
    function FindMinPath(constref aSrc, aDst: TVertex; out aPath: TIntArray; out aWeight: TWeight): Boolean; inline;
    function FindMinPathI(aSrc, aDst: SizeInt; out aPath: TIntArray; out aWeight: TWeight): Boolean;
  { finds the path of minimal weight from a aSrc to aDst if it exists;
    the weights of all edges must be nonnegative; used A* algorithm if aEst <> nil }
    function MinPathAStar(constref aSrc, aDst: TVertex; out aWeight: TWeight; aEst: TEstimate): TIntArray; inline;
    function MinPathAStarI(aSrc, aDst: SizeInt; out aWeight: TWeight; aEst: TEstimate): TIntArray;
  { creates a matrix of weights of edges }
    function CreateWeightsMatrix: TWeightMatrix; inline;
  { returns True and the shortest paths between all pairs of vertices in matrix aPaths
    if non empty and no negative weight cycles exist,
    otherwise returns False and if negative weight cycle exists then in single cell of aPaths
    returns index of the vertex from which this cycle is reachable }
    function FindAllPairMinPaths(out aPaths: TApspMatrix): Boolean;
    function ExtractMinPath(constref aSrc, aDst: TVertex; constref aPaths: TApspMatrix): TIntArray; inline;
    function ExtractMinPathI(aSrc, aDst: SizeInt; constref aPaths: TApspMatrix): TIntArray;
  { returns False if is empty or exists  negative weight cycle reachable from aVertex,
    otherwise returns True and the weighted eccentricity of the aVertex in aValue }
    function FindEccentricity(constref aVertex: TVertex; out aValue: TWeight): Boolean; inline;
    function FindEccentricityI(aIndex: SizeInt; out aValue: TWeight): Boolean;
  { returns False if is not connected or exists negative weight cycle, otherwise
    returns True and weighted radus and diameter of the graph }
    function FindWeightedMerics(out aRadius, aDiameter: TWeight): Boolean;
  { returns False if is not connected or exists negative weight cycle, otherwise
    returns True and indices of the central vertices in aCenter }
    function FindWeightedCenter(out aCenter: TIntArray): Boolean;
{**********************************************************************************************************
  minimum spanning tree utilities
***********************************************************************************************************}

  { finds a spanning tree(or spanning forest if not connected) of minimal weight, Kruskal's algorithm used }
    function MinSpanningTreeKrus(out aTotalWeight: TWeight): TIntArray;
  { finds a spanning tree(or spanning forest if not connected) of minimal weight, Prim's algorithm used }
    function MinSpanningTreePrim(out aTotalWeight: TWeight): TIntArray;
{**********************************************************************************************************
  matching utilities
***********************************************************************************************************}

  { returns True if aMatch is maximal matching }
    function IsMaximalMatching(const aMatch: TEdgeArray): Boolean; inline;
  { returns True if aMatch is perfect matching }
    function IsPerfectWeightMatching(const aMatch: TEdgeArray): Boolean; inline;
  end;

  TRealWeight = specialize TGSimpleWeight<ValReal>;

  { TPointsChart }
  TPointsChart = class(specialize TGWeightedGraph<TPoint, ValReal, TRealWeight, TPoint>)
  protected
    procedure OnAddEdge(constref aSrc, aDst: TPoint; aData: PEdgeData);
    procedure WritePoint(aStream: TStream; constref aValue: TPoint);
    procedure ReadPoint(aStream: TStream; out aValue: TPoint);
    procedure WriteData(aStream: TStream; constref aValue: TRealWeight);
    procedure ReadData(aStream: TStream; out aValue: TRealWeight);
  public
    class function Distance(constref aSrc, aDst: TPoint): ValReal; static;
    constructor Create;
    function  AddEdge(constref aSrc, aDst: TPoint): Boolean;
    function  AddEdgeI(aSrc, aDst: SizeInt): Boolean;
    function  EnsureConnected(aOnAddEdge: TOnAddEdge = nil): SizeInt;
    function  RemoveCutPoints(constref aRoot: TPoint; aOnAddEdge: TOnAddEdge = nil): SizeInt;
    function  RemoveCutPointsI(aRoot: SizeInt; aOnAddEdge: TOnAddEdge = nil): SizeInt;
    function  EnsureBiconnected(aOnAddEdge: TOnAddEdge = nil): SizeInt;
    function  SeparateGraph(aVertex: TPoint): TPointsChart;
    function  SeparateGraphI(aIndex: SizeInt): TPointsChart;
    function  SubgraphFromVertexList(const aList: TIntArray): TPointsChart;
    function  SubgraphFromTree(const aTree: TIntArray): TPointsChart;
    function  SubgraphFromEdges(const aEdges: TIntEdgeArray): TPointsChart;
    function  Clone: TPointsChart;
    function  MinPathAStar(constref aSrc, aDst: TPoint; out aWeight: ValReal; aHeur: TEstimate = nil): TIntArray; inline;
    function  MinPathAStarI(aSrc, aDst: SizeInt; out aWeight: ValReal; aHeur: TEstimate = nil): TIntArray;
  end;

  { TGIntWeightGraph specializes TWeight with Int64 }
  generic TGIntWeightGraph<TVertex, TEdgeData, TEqRel> = class(
    specialize TGWeightedGraph<TVertex, Int64, TEdgeData, TEqRel>)
  public
  type
    TWeight = Int64;

  protected
  const
    MAX_WEIGHT = High(Int64);
    MIN_WEIGHT = Low(Int64);

    {$I IntGraphHelpH.inc}

    function GetTrivialMinCut(out aCutSet: TIntSet; out aCutWeight: TWeight): Boolean;
    function GetTrivialMinCut(out aCut: TWeight): Boolean;
    function StoerWagner(out aCut: TIntSet): TWeight;
  public
{**********************************************************************************************************
  class management utilities
***********************************************************************************************************}
    function SeparateGraph(constref aVertex: TVertex): TGIntWeightGraph;
    function SeparateGraphI(aIndex: SizeInt): TGIntWeightGraph;
    function SubgraphFromVertexList(const aList: TIntArray): TGIntWeightGraph;
    function SubgraphFromTree(const aTree: TIntArray): TGIntWeightGraph;
    function SubgraphFromEdges(const aEdges: TIntEdgeArray): TGIntWeightGraph;
    function Clone: TGIntWeightGraph;
{**********************************************************************************************************
  matching utilities
***********************************************************************************************************}

  { returns False if graph is not bipartite, otherwise in aMatch returns the matching of
    the maximum cardinality and minimum weight }
    function FindBipartiteMinWeightMatching(out aMatch: TEdgeArray): Boolean;
  { returns False if graph is not bipartite, otherwise in aMatch returns the matching of
    the maximum cardinality and maximum weight }
    function FindBipartiteMaxWeightMatching(out aMatch: TEdgeArray): Boolean;
{**********************************************************************************************************
  networks utilities treat the weight of the edge as its capacity
***********************************************************************************************************}

  { returns the global minimum cut; the weights of all edges must be nonnegative;
    used Stoer–Wagner algorithm }
    function MinWeightCutSW(out aCut: TCut): TWeight;
  { returns the global minimum cut; the weights of all edges must be nonnegative;
    used Nagamochi-Ibaraki algorithm }
    function MinWeightCutNI: TWeight;
    function MinWeightCutNI(out aCut: TCut): TWeight;
  { returns array of the edges that cross the minimum cut }
    function CrossMinWeightCut: TEdgeArray;
  end;

implementation
{$B-}{$COPERATORS ON}{$POINTERMATH ON}

uses
  bufstream;

{ TGSimpleGraph.TNodeSearch }

function TGSimpleGraph.TNodeSearch.TimeOut: Boolean;
begin
  FCancelled := SecondsBetween(Now, FStartTime) >= FTimeOut;
  Result := FCancelled;
end;

{$I SimpGraphHelp.inc}

{ TGSimpleGraph.TDistinctEdgeEnumerator }

function TGSimpleGraph.TDistinctEdgeEnumerator.GetCurrent: TEdge;
begin
  Result := TEdge.Create(FCurrIndex, FEnum.Current);
end;

function TGSimpleGraph.TDistinctEdgeEnumerator.MoveNext: Boolean;
begin
  repeat
    if FEnumDone then
      begin
        if FCurrIndex >= FLastIndex then
          exit(False);
        Inc(FCurrIndex);
        FEnum := FList[FCurrIndex].AdjList.GetEnumerator;
      end;
    Result := FEnum.MoveNext;
    FEnumDone := not Result;
    if Result then
      Result := FEnum.Current^.Destination > FCurrIndex;
  until Result;
end;

procedure TGSimpleGraph.TDistinctEdgeEnumerator.Reset;
begin
  FCurrIndex := -1;
  FEnumDone := True;
end;

{ TGSimpleGraph.TDistinctEdges }

function TGSimpleGraph.TDistinctEdges.GetEnumerator: TDistinctEdgeEnumerator;
begin
  Result.FList := Pointer(FGraph.FNodeList);
  Result.FLastIndex := Pred(FGraph.VertexCount);
  Result.FCurrIndex := -1;
  Result.FEnumDone := True;
end;

{ TGSimpleGraph }

procedure TGSimpleGraph.ResetTags;
var
  I: SizeInt;
begin
  for I := 0 to Pred(VertexCount) do
    FNodeList[I].Tag := I;
end;

function TGSimpleGraph.SeparateTag(aIndex: SizeInt): SizeInt;
begin
  if FNodeList[aIndex].Tag = aIndex then
    exit(aIndex);
  Result := SeparateTag(FNodeList[aIndex].Tag);
  FNodeList[aIndex].Tag := Result;
end;

function TGSimpleGraph.SeparateJoin(L, R: SizeInt): Boolean;
begin
  L := SeparateTag(L);
  R := SeparateTag(R);
  if L = R then
    exit(False);
  if NextRandomBoolean then
    FNodeList[L].Tag := R
  else
    FNodeList[R].Tag := L;
  Result := True;
end;

procedure TGSimpleGraph.ValidateConnected;
var
  Queue: TIntQueue;
  Visited: TBitVector;
  I, Curr, Next: SizeInt;
begin
  if ConnectedValid then
    exit;
  if IsEmpty then
    begin
      FCompCount := 0;
      FConnectedValid := True;
      exit;
    end;
  Visited.Size := VertexCount;
  FCompCount := VertexCount;
  ResetTags;
  for I := 0 to Pred(VertexCount) do
    if not Visited[I] then
      begin
        Curr := I;
        Visited[Curr] := True;
        repeat
          for Next in AdjVerticesI(Curr) do
            if not Visited[Next] then
              begin
                Visited[Next] := True;
                Queue.Enqueue(Next);
                if SeparateJoin(Curr, Next) then
                  Dec(FCompCount);
              end;
        until not Queue{%H-}.TryDequeue(Curr);
      end;
  FConnected := FCompCount = 1;
  FConnectedValid := True;
end;

function TGSimpleGraph.GetConnected: Boolean;
begin
  Result := SeparateCount = 1;
end;

function TGSimpleGraph.GetDensity: Double;
begin
  if NonEmpty then
    Result := (Double(EdgeCount) * 2)/(Double(VertexCount) * Double(Pred(VertexCount)))
  else
    Result := 0.0;
end;

procedure TGSimpleGraph.DoRemoveVertex(aIndex: SizeInt);
var
  CurrEdges: TAdjList.TAdjItemArray;
  I, J: SizeInt;
begin
  FEdgeCount -= FNodeList[aIndex].AdjList.Count;
  Delete(aIndex);
  FConnectedValid := False;
  for I := 0 to Pred(VertexCount) do
    begin
      CurrEdges := FNodeList[I].AdjList.ToArray;
      FNodeList[I].AdjList.MakeEmpty;
      for J := 0 to System.High(CurrEdges) do
        begin
          if CurrEdges[J].Destination <> aIndex then
            begin
              if CurrEdges[J].Destination > aIndex then
                Dec(CurrEdges[J].Destination);
              FNodeList[I].AdjList.Add(CurrEdges[J]);
            end;
        end;
    end;
end;

function TGSimpleGraph.DoAddEdge(aSrc, aDst: SizeInt; aData: TEdgeData): Boolean;
begin
  if aSrc = aDst then
    exit(False);
  Result := FNodeList[aSrc].AdjList.Add(TAdjItem.Create(aDst, aData));
  if Result then
    begin
      if FNodeList[aDst].AdjList.Add(TAdjItem.Create(aSrc, aData)) then
        begin
          Inc(FEdgeCount);
          if ConnectedValid and SeparateJoin(aSrc, aDst) then
            begin
              Dec(FCompCount);
              FConnected := FCompCount = 1;
            end;
        end
      else
        raise EGraphError.Create(SEInternalDataInconsist);
    end;
end;

function TGSimpleGraph.DoRemoveEdge(aSrc, aDst: SizeInt): Boolean;
begin
  if aSrc = aDst then
    exit(False);
  Result := FNodeList[aSrc].AdjList.Remove(aDst);
  if Result then
    begin
      FNodeList[aDst].AdjList.Remove(aSrc);
      Dec(FEdgeCount);
      FConnectedValid := False;
    end;
end;

function TGSimpleGraph.CreateSkeleton: TSkeleton;
var
  I: SizeInt;
begin
  Result := TSkeleton.Create(VertexCount);
  Result.FEdgeCount := EdgeCount;
  for I := 0 to Pred(VertexCount) do
    Result[I]^.AssignList(AdjLists[I]);
end;

procedure TGSimpleGraph.AssignGraph(aGraph: TGSimpleGraph);
var
  I: SizeInt;
begin
  Clear;
  FCount := aGraph.VertexCount;
  FEdgeCount := aGraph.EdgeCount;
  FCompCount := aGraph.FCompCount;
  FTitle := aGraph.Title;
  FDescription.Assign(aGraph.FDescription);
  FConnected := aGraph.Connected;
  FConnectedValid := aGraph.ConnectedValid;
  if aGraph.NonEmpty then
    begin
      FChainList := System.Copy(aGraph.FChainList);
      System.SetLength(FNodeList, System.Length(aGraph.FNodeList));
      for I := 0 to Pred(VertexCount) do
        FNodeList[I].Assign(aGraph.FNodeList[I]);
    end;
end;

procedure TGSimpleGraph.AssignSeparate(aGraph: TGSimpleGraph; aIndex: SizeInt);
var
  v: TIntArray;
  I, J, Tag: SizeInt;
begin
  v.Length := aGraph.SeparatePopI(aIndex);
  Tag := aGraph.SeparateTag(aIndex);
  J := 0;
  for I := 0 to Pred(aGraph.VertexCount) do
    if aGraph.FNodeList[I].Tag = Tag then
      begin
        v[J] := I;
        Inc(J);
      end;
  AssignVertexList(aGraph, v);
end;

procedure TGSimpleGraph.AssignVertexList(aGraph: TGSimpleGraph; const aList: TIntArray);
var
  VertSet: TBitVector;
  I: SizeInt;
  p: PAdjItem;
begin
  Clear;
  VertSet.Size := aGraph.VertexCount;
  for I in aList do
    begin
      {%H-}AddVertex(aGraph[I]);
      VertSet[I] := True;
    end;
  for I in aList do
    for p in aGraph.AdjLists[I]^ do
      if VertSet[p^.Key] then
        AddEdge(aGraph[I], aGraph[p^.Key], aGraph.GetEdgeDataPtr(I, p^.Key)^);
end;

procedure TGSimpleGraph.AssignTree(aGraph: TGSimpleGraph; const aTree: TIntArray);
var
  I, Src: SizeInt;
begin
  Clear;
  for I := 0 to Pred(System.Length(aTree)) do
    begin
      {%H-}AddVertex(aGraph[I]);
      Src := aTree[I];
      if Src <> -1 then
        AddEdge(aGraph[Src], aGraph[I], aGraph.GetEdgeDataPtr(Src, I)^);
    end;
end;

procedure TGSimpleGraph.AssignEdges(aGraph: TGSimpleGraph; const aEdges: TIntEdgeArray);
var
  e: TIntEdge;
begin
  Clear;
  for e in aEdges do
    AddEdge(aGraph[e.Source], aGraph[e.Destination], aGraph.GetEdgeDataPtr(e.Source, e.Destination)^);
end;

function TGSimpleGraph.GetSeparateGraph(aIndex: SizeInt): TGSimpleGraph;
var
  I, J: SizeInt;
  d: TEdgeData;
begin
  Result := TGSimpleGraph.Create;
  J := SeparateTag(aIndex);
  for I := 0 to Pred(VertexCount) do
    if SeparateTag(I) = J then
       {%H-}Result.AddVertex(Items[I]);
  for I := 0 to Pred(Result.VertexCount) do
    for J := Succ(I) to Pred(Result.VertexCount) do
      if Adjacent(Result[I], Result[J]) then
        begin
          if not GetEdgeData(Result[I], Result[J], d) then
            raise EGraphError.Create(SEInternalDataInconsist);
          Result.AddEdgeI(I, J, d);
        end;
end;

function TGSimpleGraph.GetSeparateCount: SizeInt;
begin
  if not ConnectedValid then
    ValidateConnected;
  Result := FCompCount;
end;

function TGSimpleGraph.CountPop(aTag: SizeInt): SizeInt;
var
  I: SizeInt;
begin
  Result := 0;
  for I := 0 to Pred(VertexCount) do
    Result += Ord(SeparateTag(I) = aTag);
end;

function TGSimpleGraph.MakeConnected(aOnAddEdge: TOnAddEdge): SizeInt;
var
  I: SizeInt;
  d: TEdgeData;
begin
  Result := 0;
  d := Default(TEdgeData);
  for I := 1 to Pred(VertexCount) do
    if SeparateTag(0) <> SeparateTag(I) then
      begin
        if Assigned(aOnAddEdge) then
          aOnAddEdge(FNodeList[0].Vertex, FNodeList[I].Vertex, @d);
        AddEdgeI(0, I, d);
        Inc(Result);
      end;
end;

function TGSimpleGraph.CycleExists(aRoot: SizeInt; out aCycle: TIntArray): Boolean;
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  Parents: TIntArray;
  Visited: TBitVector;
  Next: SizeInt;
begin
  Stack := TSimpleStack.Create(VertexCount);
  AdjEnums := CreateAdjEnumArray;
  Parents := CreateIntArray;
  Visited.Size := VertexCount;
  Visited[aRoot] := True;
  {%H-}Stack.Push(aRoot);
  while Stack.TryPeek(aRoot) do
    if AdjEnums[aRoot].MoveNext then
      begin
        Next := AdjEnums[aRoot].Current;
        if not Visited[Next] then
          begin
            Visited[Next] := True;
            Parents[Next] := aRoot;
            Stack.Push(Next);
          end
        else
          if Parents[aRoot] <> Next then
            begin
              aCycle := TreePathFromTo(Parents, Next, aRoot);
              exit(True);
            end;
      end
    else
      Stack.Pop;
  Result := False;
end;

function TGSimpleGraph.GetMaxCliqueBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPCliqueIsHelper;
begin
  Result := Helper.MaxClique(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetMaxCliqueBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPCliqueIsHelper256;
begin
  Result := Helper.MaxClique(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetMaxClique(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TCliqueHelper;
begin
  Result := Helper.MaxClique(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GreedyMatching: TIntEdgeArray;
var
  Nodes: TIntArray;
  Matched: TBitVector;
  CurrPos, Size, Curr, Next: SizeInt;
  p: PAdjItem;
begin
  Nodes := SortNodesByDegree(soAsc);
  Matched.Size := VertexCount;
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  CurrPos := 0;
  Size := 0;
  while CurrPos < VertexCount do
    begin
      if not Matched[Nodes[CurrPos]] then
        begin
          Curr := Nodes[CurrPos];
          Next := NULL_INDEX;
          for p in AdjLists[Curr]^ do // find adjacent non matched node
            if not Matched[p^.Destination] then
              begin
                Next := p^.Destination;
                break;
              end;
          if Next <> NULL_INDEX then // node found
            begin
              Matched[Curr] := True;
              Matched[Next] := True;
              if System.Length(Result) = Size then
                System.SetLength(Result, Size shl 1);
              Result[Size] := TIntEdge.Create(Curr, Next);
              Inc(Size);
            end;
        end;
      Inc(CurrPos);
    end;
  System.SetLength(Result, Size);
end;

function TGSimpleGraph.GreedyMatching2: TIntEdgeArray;
var
  Nodes: TINodePqMin;
  Matched: TBitVector;
  Node: TIntNode;
  Size, I, Deg, s, d: SizeInt;
  p: PAdjItem;
begin
  Nodes := TINodePqMin.Create(VertexCount);
  for I := 0 to Pred(VertexCount) do
    {%H-}Nodes.Enqueue(I, TIntNode.Create(I, DegreeI(I)));
  Matched.Size := VertexCount;
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  Size := 0;
  while Nodes.TryDequeue(Node) do
    if not Matched[{%H-}Node.Index] then
      begin
        s := Node.Index;
        d := NULL_INDEX;
        Deg := VertexCount;
        for p in AdjLists[s]^ do // find adjacent node with min degree
          begin
            I := p^.Destination;
            if not Matched[I] then
              begin
                Node := Nodes.Peek(I);
                if  Node.Data < Deg then
                  begin
                    Deg := Node.Data;
                    d := I;
                  end;
                Dec(Node.Data);
                Nodes.Update(I, Node);
              end;
          end;
        if d <> NULL_INDEX then // node found
          begin
            for p in AdjLists[d]^ do
              begin
                I := p^.Destination;
                if (I <> s) and not Matched[I] then
                  begin
                    Node := Nodes.Peek(I);
                    Dec(Node.Data);
                    Nodes.Update(I, Node);
                  end;
              end;
            Matched[s] := True;
            Matched[d] := True;
            Nodes.Remove(d);
            if System.Length(Result) = Size then
              System.SetLength(Result, Size shl 1);
            Result[Size] := TIntEdge.Create(s, d);
            Inc(Size);
          end;
      end;
  System.SetLength(Result, Size);
end;

function TGSimpleGraph.GetMvMatching: TIntEdgeArray;
var
  Nodes: LGMvMatch.TNodes;
  Edgs: LGMvMatch.TEdges;
  I, J, Matched, NodeCount, Mate: SizeInt;
  e: TEdge;
  ie: TIntEdge;
begin
  Matched := 0;
  NodeCount := VertexCount;
  System.SetLength(Nodes, NodeCount);
  for I := 0 to Pred(NodeCount) do
    begin
      Nodes[I].Mate := nil;
      Nodes[I].FirstEdge := nil;
    end;

  for ie in GreedyMatching2 do
    begin
      Nodes[ie.Source].Mate := @Nodes[ie.Destination];
      Nodes[ie.Destination].Mate := @Nodes[ie.Source];
      Inc(Matched);
    end;

  System.SetLength(Edgs, EdgeCount);
  I := 0;
  for e in {%H-}DistinctEdges do
    begin
      Edgs[I].Node1 := @Nodes[e.Source];
      Edgs[I].Next1 := Nodes[e.Source].FirstEdge;
      Nodes[e.Source].FirstEdge := @Edgs[I];
      Edgs[I].Node2 := @Nodes[e.Destination];
      Edgs[I].Next2 := Nodes[e.Destination].FirstEdge;
      Nodes[e.Destination].FirstEdge := @Edgs[I];

      if Nodes[e.Source].Matched and (Nodes[e.Source].Mate = @Nodes[e.Destination]) then
        begin
          Nodes[e.Source].MatchedEdge := @Edgs[I];
          Nodes[e.Destination].MatchedEdge := @Edgs[I];
        end;

      Inc(I);
    end;

  LGMvMatch.Match(Nodes, Edgs, Matched);
  Edgs := nil;

  System.SetLength(Result, Matched);
  J := 0;
  for I := 0 to System.High(Nodes) do
    if Nodes[I].Matched then
      begin
        Mate := SizeInt(Nodes[I].Mate - LGMvMatch.PNode(Nodes));
        Result[J] := TIntEdge.Create(I, Mate);
        Nodes[Mate].Mate := nil;
        Inc(J);
      end;
end;

procedure TGSimpleGraph.ListCliquesBP(aOnFind: TOnFindSet);
var
  Helper: TBPCliqueIsHelper;
begin
  Helper.ListCliques(Self, aOnFind);
end;

procedure TGSimpleGraph.ListCliquesBP256(aOnFind: TOnFindSet);
var
  Helper: TBPCliqueIsHelper256;
begin
  Helper.ListCliques(Self, aOnFind);
end;

procedure TGSimpleGraph.ListCliques(aOnFind: TOnFindSet);
var
  Helper: TCliqueHelper;
begin
  Helper.ListCliques(Self, aOnFind);
end;

function TGSimpleGraph.GetMaxIsBipartite(const w, g: TIntArray): TIntArray;
var
  Helper: THKMatch;
  Lefts, LeftsVisit, LeftsFree, RightsUnvisit: TBoolVector;
  Match: TIntArray;
  e: TIntEdge;
  Stack: TIntStack;
  Visited: TBitVector;
  AdjEnums: TAdjEnumArray;
  I, Curr, Next: SizeInt;
  CurrInLefts: Boolean;
begin
  Lefts.Size := VertexCount;
  LeftsVisit.Size := VertexCount;
  LeftsFree.Size := VertexCount;
  RightsUnvisit.Size := VertexCount;
  if System.Length(w) < System.Length(g) then
    begin
      for I in w do
        begin
          Lefts[I] := True;
          LeftsFree[I] := True;
        end;
      for I in g do
        RightsUnvisit[I] := True;
    end
  else
    if System.Length(w) > System.Length(g) then
      begin
        for I in g do
          begin
            Lefts[I] := True;
            LeftsFree[I] := True;
          end;
        for I in w do
          RightsUnvisit[I] := True;
      end
    else
      exit(w); ////

  Match := CreateIntArray;
  for e in Helper.MaxMatching(Self, w, g) do
    begin
      LeftsFree[e.Source] := False;
      LeftsFree[e.Destination] := False;
      Match[e.Source] := e.Destination;
      Match[e.Destination] := e.Source;
    end;

  //find nodes that not belong min vertex cover
  Visited.Size := VertexCount;
  AdjEnums := CreateAdjEnumArray;
  for I in LeftsFree do
    begin
      {%H-}Stack.Push(I);
      Visited[I] := True;
      while Stack.TryPeek(Curr) do
        begin
          CurrInLefts := Lefts[Curr];
          if AdjEnums[Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if not Visited[Next] then
                begin
                  Visited[Next] := True;
                  if CurrInLefts xor (Match[Curr] = Next) then
                    Stack.Push(Next);
                end;
            end
          else
            begin
              Stack.Pop;
              if CurrInLefts then
                LeftsVisit[Curr] := True
              else
                RightsUnvisit[Curr] := False;
            end;
        end;
    end;

  Match := nil;
  Lefts.Size := 0;
  LeftsFree.Size := 0;

  System.SetLength(Result, LeftsVisit.PopCount + RightsUnvisit.PopCount);
  I := 0;
  for Curr in LeftsVisit do
    begin
      Result[I] := Curr;
      Inc(I);
    end;
  for Curr in RightsUnvisit do
    begin
      Result[I] := Curr;
      Inc(I);
    end;
end;

function TGSimpleGraph.GetMaxIsBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPCliqueIsHelper;
begin
  Result := Helper.MaxIS(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetMaxIsBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPCliqueIsHelper256;
begin
  Result := Helper.MaxIS(Self, aTimeOut, aExact);
end;

procedure TGSimpleGraph.ListIsBP(aOnFind: TOnFindSet);
var
  Helper: TBPCliqueIsHelper;
begin
  Helper.ListIS(Self, aOnFind);
end;

procedure TGSimpleGraph.ListIsBP256(aOnFind: TOnFindSet);
var
  Helper: TBPCliqueIsHelper256;
begin
  Helper.ListIS(Self, aOnFind);
end;

function TGSimpleGraph.GetGreedyMis: TIntArray;
var
  Cand, Stack: TIntSet;
  I, J, CurrPop, MinPop: SizeInt;
begin
  Cand.InitRange(VertexCount);
  while Cand.NonEmpty do
    begin
      J := 0;
      MinPop := VertexCount;
      for I in Cand do
        begin
          CurrPop := Succ(Cand.IntersectionCount(AdjLists[I]));
          if CurrPop < MinPop then
            begin
              MinPop := CurrPop;
              J := I;
            end;
        end;
      Cand.Subtract(AdjLists[J]);
      Cand.Delete(J);
      {%H-}Stack.Push(J);
    end;
  Result := Stack.ToArray;
end;

function TGSimpleGraph.GetGreedyMisBP: TIntArray;
var
  Matrix: TBoolMatrix;
  Cand: TBoolVector;
  Stack: TIntSet;
  I, J, CurrPop, MinPop: SizeInt;
begin
  Matrix := CreateBoolMatrix;
  Cand.InitRange(VertexCount);
  while Cand.NonEmpty do
    begin
      J := 0;
      MinPop := VertexCount;
      for I in Cand do
        begin
          CurrPop := Succ(Cand.IntersectionPop(Matrix[I]));
          if CurrPop < MinPop then
            begin
              MinPop := CurrPop;
              J := I;
            end;
        end;
      Cand[J] := False;
      Cand.Subtract(Matrix[J]);
      {%H-}Stack.Push(J);
    end;
  Result := Stack.ToArray;
end;

function TGSimpleGraph.GetGreedyMinIs: TIntArray;
var
  Cand, Stack: TIntSet;
  I, J, CurrPop, MaxPop: SizeInt;
begin
  Cand.InitRange(VertexCount);
  while Cand.NonEmpty do
    begin
      J := 0;
      MaxPop := 0;
      for I in Cand do
        begin
          CurrPop := Succ(Cand.IntersectionCount(AdjLists[I]));
          if CurrPop > MaxPop then
            begin
              MaxPop := CurrPop;
              J := I;
            end;
        end;
      Cand.Subtract(AdjLists[J]);
      Cand.Delete(J);
      {%H-}Stack.Push(J);
    end;
  Result := Stack.ToArray;
end;

function TGSimpleGraph.GetGreedyMinIsBP: TIntArray;
var
  Matrix: TBoolMatrix;
  Cand: TBoolVector;
  Stack: TIntSet;
  I, J, CurrPop, MaxPop: SizeInt;
begin
  Matrix := CreateBoolMatrix;
  Cand.InitRange(VertexCount);
  while Cand.NonEmpty do
    begin
      J := 0;
      MaxPop := 0;
      for I in Cand do
        begin
          CurrPop := Succ(Cand.IntersectionPop(Matrix[I]));
          if CurrPop > MaxPop then
            begin
              MaxPop := CurrPop;
              J := I;
            end;
        end;
      Cand.Subtract(Matrix[J]);
      Cand[J] := False;
      {%H-}Stack.Push(J);
    end;
  Result := Stack.ToArray;
end;

function TGSimpleGraph.GetMdsBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPDomSetHelper;
begin
  Result := Helper.MinDomSet(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetMdsBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPDomSetHelper256;
begin
  Result := Helper.MinDomSet(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetMds(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TDomSetHelper;
begin
  Result := Helper.MinDomSet(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.ColorTrivial(out aMaxColor: SizeInt; out aColors: TIntArray): Boolean;
var
  Cycle: TIntArray;
  Cols: TColorArray;
  I, Hub: SizeInt;
begin
  aMaxColor := 0;
  aColors := nil;
  if IsEmpty then
    exit(True);
  if {%H-}IsComplete then
    begin
      aColors.Length := VertexCount;
      for I := 0 to Pred(VertexCount) do
        aColors[I] := Succ(I);
      aMaxColor := VertexCount;
      exit(True);
    end;
  if IsBipartite(Cols) then
    begin
      aColors.Length := VertexCount;
      for I := 0 to System.High(aColors) do
        aColors[I] := Cols[I];
      aMaxColor := 2;
      exit(True);
    end;
  if Odd(VertexCount) and IsCycle then
    begin
      if not CycleExists(0, Cycle) then
        exit(False); //todo: internal error ???
      aColors.Length := VertexCount;
      for I := 0 to VertexCount - 2 do
        aColors[Cycle[I]] := Succ(Ord(Odd(I)));
      aColors[Cycle[Pred(VertexCount)]] := 3;
      aMaxColor := 3;
      exit(True);
    end;
  if IsWheel(Hub) then
    begin
      if Hub <> 0 then
        I := 0
      else
        I := 1;
      if not CycleExists(I, Cycle) then
        exit(False); //todo: internal error ???
      aColors.Length := VertexCount;
      aColors[Hub] := 1;
      for I := 0 to VertexCount - 3 do
        aColors[Cycle[I]] := Ord(Odd(I)) + 2;
      if Odd(VertexCount) then
        aMaxColor := 3
      else
        aMaxColor := 4;
      aColors[Cycle[VertexCount - 2]] := aMaxColor;
      exit(True);
    end;
  Result := False;
end;

function TGSimpleGraph.ColorConnected(aTimeOut: Integer; out aColors: TIntArray; out aExact: Boolean): SizeInt;
var
  Helper: TExactColor;
begin
  Result := Helper.Colorize(Self, aTimeOut, aColors, aExact);
end;

function TGSimpleGraph.ColorDisconnected(aTimeOut: Integer; out aColors: TIntArray; out aExact: Boolean): SizeInt;
var
  Separates: TIntVectorArray;
  g: TGSimpleGraph;
  ColMap: TIntArray;
  I, J, ColCount, MaxColCount: SizeInt;
  TimeOut: Integer;
  StartTime: TDateTime;
  Exact: Boolean;
begin
  aExact := False;
  TimeOut := aTimeOut and System.High(Integer);
  StartTime := Now;
  Result := GreedyColorRlf(aColors);
  if SecondsBetween(Now, StartTime) < TimeOut then
    begin
      Separates := FindSeparates;
      MaxColCount := 0;
      for I := 0 to System.High(Separates) do
        begin
          g := SubgraphFromVertexList(Separates[I].ToArray);
          try
            ColCount := g.VertexColoring(ColMap, Exact, TimeOut - SecondsBetween(Now, StartTime));
            for J := 0 to System.High(ColMap) do
              aColors[IndexOf(g[J])] := ColMap[J];
            if ColCount > MaxColCount then
              MaxColCount := ColCount;
          finally
            g.Free;
          end;
          if not Exact then
            exit;
        end;
      if MaxColCount < Result then
        Result := MaxColCount;
      aExact := True;
    end;
end;

function TGSimpleGraph.ColorableConnected(aK: SizeInt; aTimeOut: Integer; out aColors: TIntArray): TTriLean;
var
  Helper: TExactColor;
begin
  Result := Helper.IsColorable(Self, aK, aTimeOut, aColors);
end;

function TGSimpleGraph.ColorableDisconnected(aK: SizeInt; aTimeOut: Integer; out aColors: TIntArray): TTriLean;
var
  Separates: TIntVectorArray;
  g: TGSimpleGraph;
  ColMap: TIntArray;
  I, J: SizeInt;
  TimeOut: Integer;
  StartTime: TDateTime;
begin
  TimeOut := aTimeOut and System.High(Integer);
  StartTime := Now;
  Separates := FindSeparates;
  aColors.Length := VertexCount;
  for I := 0 to System.High(Separates) do
    begin
      g := SubgraphFromVertexList(Separates[I].ToArray);
      try
        Result := g.IsKColorable(aK, ColMap, TimeOut - SecondsBetween(Now, StartTime));
        if Result = tlTrue then
          for J := 0 to System.High(ColMap) do
            aColors[IndexOf(g[J])] := ColMap[J];
      finally
        g.Free;
      end;
      if (Result = tlFalse) or (Result = tlUnknown) then
        begin
          aColors := nil;
          exit;
        end;
    end;
end;

function TGSimpleGraph.GreedyColorRlf(out aColors: TIntArray): SizeInt;
var
  Helper: TGreedyColorRlf;
begin
  Result := Helper.Execute(Self, aColors);
end;

function TGSimpleGraph.GreedyColor(out aColors: TIntArray): SizeInt;
var
  Queue: TINodePqMax;
  Nodes: array of TIntNode;
  Achromatic, CurrIS: TBoolVector;
  Node: TIntNode;
  I: SizeInt;
  pItem: PAdjItem;
begin
  System.SetLength(Nodes, VertexCount);
  for I := 0 to Pred(VertexCount) do
    Nodes[I] := TIntNode.Create(I, AdjLists[I]^.Count);
  Queue := TINodePqMax.Create(VertexCount);
  aColors.Length := VertexCount;
  Achromatic.InitRange(VertexCount);
  Result := 0;
  while Achromatic.NonEmpty do
    begin
      Inc(Result);
      CurrIS := Achromatic;
      for I in Achromatic do
        {%H-}Queue.Enqueue(I, Nodes[I]);
      while Queue.TryDequeue(Node) do
        if CurrIS[Node.Index] then
          begin
            CurrIS[Node.Index] := False;
            Achromatic[Node.Index] := False;
            aColors[Node.Index] := Result;
            for pItem in AdjLists[Node.Index]^ do
              if Achromatic[pItem^.Key] then
                begin
                  Dec(Nodes[pItem^.Key].Data);
                  CurrIS[pItem^.Key] := False;
                end;
          end;
    end;
end;

procedure TGSimpleGraph.SearchForCutVertices(aRoot: SizeInt; var aPoints: TIntHashSet);
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents: TIntArray;
  Counter, Curr, Next, ChildCount: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  PreOrd[aRoot] := 0;
  LowPt[aRoot] := 0;
  Stack.Push(aRoot);
  Counter := 1;
  ChildCount := 0;
  while Stack.TryPeek(Curr) do
    if AdjEnums[{%H-}Curr].MoveNext then
      begin
        Next := AdjEnums[Curr].Current;
        if Next <> Parents[Curr] then
          if PreOrd[Next] = NULL_INDEX then
            begin
              Parents[Next] := Curr;
              PreOrd[Next] := Counter;
              LowPt[Next] := Counter;
              Inc(Counter);
              ChildCount += Ord(Curr = aRoot);
              Stack.Push(Next);
            end
          else
            if LowPt[Curr] > PreOrd[Next] then
              LowPt[Curr] := PreOrd[Next];
      end
    else
      begin
        Next := Stack.Pop;
        Curr := Parents[Curr];
        if LowPt[Curr] > LowPt[Next] then
          LowPt[Curr] := LowPt[Next];
        if (LowPt[Next] >= PreOrd[Curr]) and (Curr <> aRoot) then
          aPoints.Add(Curr);
      end;
  if ChildCount > 1 then
    aPoints.Add(aRoot);
end;

function TGSimpleGraph.CutVertexExists(aRoot: SizeInt): Boolean;
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents: TIntArray;
  Counter, Curr, Next, ChildCount: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  PreOrd[aRoot] := 0;
  LowPt[aRoot] := 0;
  Stack.Push(aRoot);
  Counter := 1;
  ChildCount := 0;
  while Stack.TryPeek(Curr) do
    if AdjEnums[{%H-}Curr].MoveNext then
      begin
        Next := AdjEnums[Curr].Current;
        if Next <> Parents[Curr] then
          if PreOrd[Next] = -1 then
            begin
              Parents[Next] := Curr;
              PreOrd[Next] := Counter;
              LowPt[Next] := Counter;
              Inc(Counter);
              Inc(ChildCount, Ord(Curr = aRoot));
              Stack.Push(Next);
            end
          else
            if LowPt[Curr] > PreOrd[Next] then
              LowPt[Curr] := PreOrd[Next];
      end
    else
      begin
        Stack.Pop;
        Next := Curr;
        Curr := Parents[Curr];
        if LowPt[Curr] > LowPt[Next] then
          LowPt[Curr] := LowPt[Next];
        if (LowPt[Next] >= PreOrd[Curr]) and (Curr <> aRoot) then
          exit(True);
      end;
  Result := ChildCount > 1;
end;

procedure TGSimpleGraph.SearchForBiconnect(aRoot: SizeInt; var aEdges: TIntEdgeVector);
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents, Across: TIntArray;
  Counter, Curr, Next: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  Across := CreateIntArray;
  PreOrd[aRoot] := 0;
  LowPt[aRoot] := 0;
  {%H-}Stack.Push(aRoot);
  Counter := 1;
  while Stack.TryPeek(Curr) do
    if AdjEnums[{%H-}Curr].MoveNext then
      begin
        Next := AdjEnums[Curr].Current;
        if Next <> Parents[Curr] then
          if PreOrd[Next] = -1 then
            begin
              if Across[Curr] = -1 then
                Across[Curr] := Next;
              Parents[Next] := Curr;
              PreOrd[Next] := Counter;
              LowPt[Next] := Counter;
              Inc(Counter);
              Stack.Push(Next);
            end
          else
            if LowPt[Curr] > PreOrd[Next] then
              LowPt[Curr] := PreOrd[Next];
      end
    else
      begin
        Stack.Pop;
        Next := Curr;
        Curr := Parents[Curr];
        if LowPt[Curr] > LowPt[Next] then
          LowPt[Curr] := LowPt[Next];
        if LowPt[Next] >= PreOrd[Curr] then
          begin
            if Next = Across[Curr] then
              begin
                if Curr <> aRoot then
                  aEdges.Add(TIntEdge.Create(Parents[Curr], Next));
              end
            else
              aEdges.Add(TIntEdge.Create(Across[Curr], Next));
          end;
      end;
end;

procedure TGSimpleGraph.SearchForBicomponent(aRoot: SizeInt; var aComp: TEdgeArrayVector);
var
  Stack: TSimpleStack;
  EdgeStack: TIntEdgeVector;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents: TIntArray;
  Counter, Curr, Next, ChildCount, I: SizeInt;
  e: TIntEdge;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  PreOrd[aRoot] := 0;
  LowPt[aRoot] := 0;
  {%H-}Stack.Push(aRoot);
  Counter := 1;
  ChildCount := 0;
  while Stack.TryPeek(Curr) do
    if AdjEnums[{%H-}Curr].MoveNext then
      begin
        Next := AdjEnums[Curr].Current;
        if Next <> Parents[Curr] then
          if PreOrd[Next] = -1 then
            begin
              Parents[Next] := Curr;
              PreOrd[Next] := Counter;
              LowPt[Next] := Counter;
              Inc(Counter);
              Inc(ChildCount, Ord(Curr = aRoot));
              Stack.Push(Next);
              EdgeStack.Add(TIntEdge.Create(Curr, Next));
            end
          else
            if LowPt[Curr] > PreOrd[Next] then
              begin
                LowPt[Curr] := PreOrd[Next];
                EdgeStack.Add(TIntEdge.Create(Curr, Next));
              end;
      end
    else
      begin
        Stack.Pop;
        Next := Curr;
        Curr := Parents[Curr];
        if LowPt[Curr] > LowPt[Next] then
          LowPt[Curr] := LowPt[Next];
        if (LowPt[Next] >= PreOrd[Curr]) and (Curr <> aRoot) then
          begin
            I := EdgeStack.Count;
            repeat
              Dec(I);
              e := EdgeStack[I];
            until (e.Source = Curr) or (e.Destination = Next);
            aComp.Add(EdgeStack.ExtractAll(I, EdgeStack.Count - I));
          end;
      end;
  if ChildCount > 1 then
    begin
      I := EdgeStack.Count;
      repeat
        Dec(I);
        e := EdgeStack[I];
      until e.Source = aRoot;
      aComp.Add(EdgeStack.ExtractAll(I, EdgeStack.Count - I));
    end;
  if EdgeStack.NonEmpty then
    aComp.Add(EdgeStack.ToArray);
end;

function TGSimpleGraph.BridgeExists: Boolean;
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents: TIntArray;
  Counter, Curr, Next, I: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  Counter := 0;
  for I := 0 to Pred(VertexCount) do
    if PreOrd[I] = -1 then
      begin
        PreOrd[I] := Counter;
        LowPt[I] := Counter;
        Inc(Counter);
        {%H-}Stack.Push(I);
        while Stack.TryPeek(Curr) do
          if AdjEnums[{%H-}Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if Next <> Parents[Curr] then
                if PreOrd[Next] = -1 then
                  begin
                    Parents[Next] := Curr;
                    PreOrd[Next] := Counter;
                    LowPt[Next] := Counter;
                    Inc(Counter);
                    Stack.Push(Next);
                  end
                else
                  if LowPt[Curr] > PreOrd[Next] then
                    LowPt[Curr] := PreOrd[Next];
            end
          else
            begin
              Stack.Pop;
              Next := Curr;
              Curr := Parents[Curr];
              if LowPt[Curr] > LowPt[Next] then
                LowPt[Curr] := LowPt[Next];
              if LowPt[Next] > PreOrd[Curr] then
                exit(True);
            end;
      end;
  Result := False;
end;

procedure TGSimpleGraph.SearchForBridges(var aBridges: TIntEdgeVector);
var
  Stack: TSimpleStack;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents: TIntArray;
  Counter, Curr, Next, I: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  Stack := TSimpleStack.Create(VertexCount);
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  Counter := 0;
  for I := 0 to Pred(VertexCount) do
    if PreOrd[I] = -1 then
      begin
        PreOrd[I] := Counter;
        LowPt[I] := Counter;
        Inc(Counter);
        {%H-}Stack.Push(I);
        while Stack.TryPeek(Curr) do
          if AdjEnums[{%H-}Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if Next <> Parents[Curr] then
                if PreOrd[Next] = -1 then
                  begin
                    Parents[Next] := Curr;
                    PreOrd[Next] := Counter;
                    LowPt[Next] := Counter;
                    Inc(Counter);
                    Stack.Push(Next);
                  end
                else
                  if LowPt[Curr] > PreOrd[Next] then
                    LowPt[Curr] := PreOrd[Next];
            end
          else
            begin
              Stack.Pop;
              Next := Curr;
              Curr := Parents[Curr];
              if LowPt[Curr] > LowPt[Next] then
                LowPt[Curr] := LowPt[Next];
              if LowPt[Next] > PreOrd[Curr] then
                aBridges.Add(TIntEdge.Create(Curr, Next));
            end;
      end;
end;

procedure TGSimpleGraph.SearchForFundamentalsCycles(out aCycles: TIntArrayVector);
var
  Stack: TSimpleStack;
  Visited: TBitVector;
  AdjEnums: TAdjEnumArray;
  Parents: TIntArray;
  EdgeSet: TIntPairSet;
  I, Curr, Next: SizeInt;
begin
  Visited.Size := VertexCount;
  Stack := TSimpleStack.Create(VertexCount);
  AdjEnums := CreateAdjEnumArray;
  Parents := CreateIntArray;
  for I := 0 to Pred(VertexCount) do
    if not Visited[I] then
      begin
        Visited[I] := True;
        Stack.Push(I);
        while Stack.TryPeek(Curr) do
          if AdjEnums[{%H-}Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if not Visited[Next] then
                begin
                  Visited[Next] := True;
                  Parents[Next] := Curr;
                  Stack.Push(Next);
                end
              else
                if (Parents[Curr] <> Next) and EdgeSet.Add(Curr, Next) then
                  aCycles.Add(TreePathFromTo(Parents, Next, Curr));
            end
          else
            Stack.Pop;
      end;
end;

procedure TGSimpleGraph.SearchForFundamentalsCyclesLen(out aCycleLens: TIntVector);
var
  Stack: TSimpleStack;
  Visited: TBitVector;
  AdjEnums: TAdjEnumArray;
  Parents: TIntArray;
  EdgeSet: TIntPairSet;
  I, Curr, Next: SizeInt;
begin
  Visited.Size := VertexCount;
  Stack := TSimpleStack.Create(VertexCount);
  AdjEnums := CreateAdjEnumArray;
  Parents := CreateIntArray;
  for I := 0 to Pred(VertexCount) do
    if not Visited[I] then
      begin
        Visited[I] := True;
        Stack.Push(I);
        while Stack.TryPeek(Curr) do
          if AdjEnums[{%H-}Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if not Visited[Next] then
                begin
                  Visited[Next] := True;
                  Parents[Next] := Curr;
                  Stack.Push(Next);
                end
              else
                if (Parents[Curr] <> Next) and EdgeSet.Add(Curr, Next) then
                  aCycleLens.Add(TreePathLen(Parents, Next, Curr));
            end
          else
            Stack.Pop;
      end;
end;

procedure TGSimpleGraph.FindFundamentalCyclesLen(out aCycleLens: TIntVector);
begin
  if {%H-}IsTree then
    exit;
  SearchForFundamentalsCyclesLen(aCycleLens);
  if aCycleLens.Count <> {%H-}CyclomaticNumber then
    raise EGraphError.Create(SEInternalDataInconsist);
  TIntVectorHelper.Sort(aCycleLens);
end;

function TGSimpleGraph.CreateDegreeArray: TIntArray;
var
  I: SizeInt;
begin
  Result := CreateIntArray;
  for I := 0 to Pred(VertexCount) do
    Result[I] := AdjLists[I]^.Count;
end;

function TGSimpleGraph.CreateComplementDegreeArray: TIntArray;
var
  I: SizeInt;
begin
  Result := CreateIntArray;
  for I := 0 to Pred(VertexCount) do
    Result[I] := VertexCount - AdjLists[I]^.Count;
end;

function TGSimpleGraph.SortNodesByWidth(o: TSortOrder): TIntArray;
var
  I, J: SizeInt;
  List, Stack: TIntSet;
  m: TBoolMatrix;
begin
  Result := CreateDegreeArray;
  List.InitRange(VertexCount);
  if VertexCount > COMMON_BP_CUTOFF then
    while List.NonEmpty do
      begin
        I := List[0];
        for J in List do
          if Result[J] < Result[I] then
            I := J;
        {%H-}Stack.Push(I);
        List.Remove(I);
        for J in List do
          if AdjLists[I]^.Contains(J) then
            Dec(Result[J]);
      end
  else
    begin
      m := CreateBoolMatrix;
      while List.NonEmpty do
        begin
          I := List[0];
          for J in List do
            if Result[J] < Result[I] then
              I := J;
          {%H-}Stack.Push(I);
          List.Remove(I);
          for J in List do
            if m[I][J] then
              Dec(Result[J]);
        end;
    end;
  Result := Stack.ToArray;
  if o = soDesc then
    TIntHelper.Reverse(Result);
end;

function TGSimpleGraph.SortComplementByWidth: TIntArray;
var
  I, J: SizeInt;
  List, Stack: TIntSet;
  m: TBoolMatrix;
begin
  Result := CreateComplementDegreeArray;
  List.InitRange(VertexCount);
  if VertexCount > COMMON_BP_CUTOFF then
    while List.NonEmpty do
      begin
        I := List[0];
        for J in List do
          if Result[J] < Result[I] then
            I := J;
        {%H-}Stack.Push(I);
        List.Remove(I);
        for J in List do
          if not AdjLists[I]^.Contains(J) then
            Dec(Result[J]);
      end
  else
    begin
      m := CreateBoolMatrix;
      while List.NonEmpty do
        begin
          I := List[0];
          for J in List do
            if Result[J] < Result[I] then
              I := J;
          {%H-}Stack.Push(I);
          List.Remove(I);
          for J in List do
            if not m[I][J] then
              Dec(Result[J]);
        end
    end;
  Result := Stack.ToArray;
  TIntHelper.Reverse(Result);
end;

function TGSimpleGraph.SortNodesByDegree(o: TSortOrder): TIntArray;
begin
  Result := CreateIntArrayRange;
  TSortByDegreeHelper.Sort(Result, @CmpByDegree, o);
end;

function TGSimpleGraph.CmpByDegree(constref L, R: SizeInt): SizeInt;
begin
  Result := SizeInt.Compare(AdjLists[L]^.Count, AdjLists[R]^.Count);
  if Result = 0 then
    if L < R then
      Result := -1
    else
      Result := 1;
end;

function TGSimpleGraph.CmpIntArrayLen(constref L, R: TIntArray): SizeInt;
begin
  if System.Length(L) > System.Length(R) then
    Result := 1
  else
    if System.Length(L) < System.Length(R) then
      Result := -1
    else
      Result := 0;
end;

class function TGSimpleGraph.MayBeEqual(L, R: TGSimpleGraph): Boolean;
var
  fcL, fcR: TIntVector;
  I: SizeInt;
begin
  if L = R then
    exit(True);
  if L.IsEmpty then
    exit(L.IsEmpty)
  else
    if R.IsEmpty then
      exit(False);
  if L.VertexCount <> R.VertexCount then
    exit(False);
  if L.EdgeCount <> R.EdgeCount then
    exit(False);
  L.FindFundamentalCyclesLen(fcL);
  R.FindFundamentalCyclesLen(fcR);
  if fcL.Count <> fcR.Count then
    exit(False);
  for I := 0 to Pred(fcL.Count) do
    if fcL[I] <> fcR[I] then
      exit(False);
  Result := True;
end;

constructor TGSimpleGraph.Create;
begin
  inherited;
  FConnectedValid := True;
end;

procedure TGSimpleGraph.Clear;
begin
  inherited;
  FCompCount := 0;
  FConnected := False;
  FConnectedValid := True;
end;

procedure TGSimpleGraph.SaveToStream(aStream: TStream);
var
  Header: TStreamHeader;
  s, d: Integer;
  Edge: TEdge;
  gTitle, Descr: utf8string;
  wbs: TWriteBufStream;
begin
  if not Assigned(OnStreamWriteVertex) then
    raise EGraphError.Create(SEStreamWriteVertMissed);
  if not Assigned(OnStreamWriteData) then
    raise EGraphError.Create(SEStreamWriteDataMissed);
{$IFDEF CPU64}
  if VertexCount > System.High(Integer) then
    raise EGraphError.CreateFmt(SEStreamSizeExceedFmt, [VertexCount]);
{$ENDIF CPU64}
  wbs := TWriteBufStream.Create(aStream);
  try
    //write header
    Header.Magic := GRAPH_MAGIC;
    Header.Version := GRAPH_HEADER_VERSION;
    gTitle := Title;
    Header.TitleLen := System.Length(gTitle);
    Descr := Description.Text;
    Header.DescriptionLen := System.Length(Descr);
    Header.VertexCount := VertexCount;
    Header.EdgeCount := EdgeCount;
    wbs.WriteBuffer(Header, SizeOf(Header));
    //write title
    if Header.TitleLen > 0 then
      wbs.WriteBuffer(Pointer(gTitle)^, Header.TitleLen);
    //write description
    if Header.DescriptionLen > 0 then
      wbs.WriteBuffer(Pointer(Descr)^, Header.DescriptionLen);
    //write Items, but does not save any info about connected
    //this should allow transfer data between directed/undirected graphs ???
    for s := 0 to Pred(Header.VertexCount) do
      OnStreamWriteVertex(wbs, FNodeList[s].Vertex);
    //write edges
    for Edge in {%H-}DistinctEdges do
      begin
        s := Edge.Source;
        d := Edge.Destination;
        wbs.WriteBuffer(NtoLE(s), SizeOf(s));
        wbs.WriteBuffer(NtoLE(d), SizeOf(d));
        OnStreamWriteData(wbs, Edge.Data);
      end;
  finally
    wbs.Free;
  end;
end;

procedure TGSimpleGraph.LoadFromStream(aStream: TStream);
var
  Header: TStreamHeader;
  s, d: Integer;
  I, Ind: SizeInt;
  Data: TEdgeData;
  Vertex: TVertex;
  gTitle, Descr: utf8string;
  rbs: TReadBufStream;
begin
  if not Assigned(OnStreamReadVertex) then
    raise EGraphError.Create(SEStreamReadVertMissed);
  if not Assigned(OnStreamReadData) then
    raise EGraphError.Create(SEStreamReadDataMissed);
  rbs := TReadBufStream.Create(aStream);
  try
    //read header
    rbs.ReadBuffer(Header, SizeOf(Header));
    if Header.Magic <> GRAPH_MAGIC then
      raise EGraphError.Create(SEUnknownGraphStreamFmt);
    if Header.Version > GRAPH_HEADER_VERSION then
      raise EGraphError.Create(SEUnsuppGraphFmtVersion);
    Clear;
    EnsureCapacity(Header.VertexCount);
    //read title
    if Header.TitleLen > 0 then
      begin
        System.SetLength(gTitle, Header.TitleLen);
        rbs.ReadBuffer(Pointer(gTitle)^, Header.TitleLen);
        FTitle := gTitle;
      end;
    //read description
    if Header.DescriptionLen > 0 then
      begin
        System.SetLength(Descr, Header.DescriptionLen);
        rbs.ReadBuffer(Pointer(Descr)^, Header.DescriptionLen);
        Description.Text := Descr;
      end;
    //read Items
    for I := 0 to Pred(Header.VertexCount) do
      begin
        OnStreamReadVertex(rbs, Vertex);
        if not AddVertex(Vertex, Ind) then
          raise EGraphError.Create(SEGraphStreamCorrupt);
        if Ind <> I then
          raise EGraphError.Create(SEGraphStreamReadIntern);
      end;
    //read edges
    Data := Default(TEdgeData);
    for I := 0 to Pred(Header.EdgeCount) do
      begin
        rbs.ReadBuffer(s, SizeOf(s));
        rbs.ReadBuffer(d, SizeOf(d));
        OnStreamReadData(rbs, Data);
        AddEdgeI(LEToN(s), LEToN(d), Data);
      end;
  finally
    rbs.Free;
  end;
end;

procedure TGSimpleGraph.SaveToFile(const aFileName: string);
var
  fs: TStream;
begin
  fs := TFileStream.Create(aFileName, fmCreate);
  try
    SaveToStream(fs);
  finally
    fs.Free;
  end;
end;

procedure TGSimpleGraph.LoadFromFile(const aFileName: string);
var
  fs: TStream;
begin
  fs := TFileStream.Create(aFileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(fs);
  finally
    fs.Free;
  end;
end;

function TGSimpleGraph.Clone: TGSimpleGraph;
begin
  Result := TGSimpleGraph.Create;
  Result.AssignGraph(Self);
end;

function TGSimpleGraph.SeparateGraph(constref aVertex: TVertex): TGSimpleGraph;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TGSimpleGraph.SeparateGraphI(aIndex: SizeInt): TGSimpleGraph;
begin
  Result := TGSimpleGraph.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self)
end;

function TGSimpleGraph.SubgraphFromVertexList(const aList: TIntArray): TGSimpleGraph;
begin
  Result := TGSimpleGraph.Create;
  Result.AssignVertexList(Self, aList);
end;

function TGSimpleGraph.SubgraphFromTree(const aTree: TIntArray): TGSimpleGraph;
begin
  Result := TGSimpleGraph.Create;
  Result.AssignTree(Self, aTree);
end;

function TGSimpleGraph.SubgraphFromEdges(const aEdges: TIntEdgeArray): TGSimpleGraph;
begin
  Result := TGSimpleGraph.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TGSimpleGraph.CreateLineGraph: TLineGraph;
var
  I, J: SizeInt;
  vI, vJ: TOrdIntPair;
  e: TEdge;
begin
  Result := TLineGraph.Create;
  Result.EnsureCapacity(EdgeCount);
  for e in {%H-}DistinctEdges do
    {%H-}Result.AddVertex(TOrdIntPair.Create(e.Source, e.Destination));
  for I := 0 to Result.VertexCount - 2 do
    begin
      vI := Result[I];
      for J := Succ(I) to Pred(Result.VertexCount) do
        begin
          vJ := Result[J];
          if (vI.Left = vJ.Left) or (vI.Left = vJ.Right) then
            Result.AddEdgeI(I, J, TIntValue.Create(vI.Left))
          else
            if (vI.Right = vJ.Left) or (vI.Right = vJ.Right) then
               Result.AddEdgeI(I, J, TIntValue.Create(vI.Right))
        end;
    end;
end;

function TGSimpleGraph.AddVertex(constref aVertex: TVertex; out aIndex: SizeInt): Boolean;
begin
  Result := not FindOrAdd(aVertex, aIndex);
  if not Result then
    exit;
  if ConnectedValid then
    begin
      FNodeList[aIndex].Tag := aIndex;
      Inc(FCompCount);
      FConnected := FCompCount = 1;
    end
  else
    FNodeList[aIndex].Tag := FCompCount;
end;

function TGSimpleGraph.AddVertex(constref aVertex: TVertex): Boolean;
var
  Dummy: SizeInt;
begin
  Result := AddVertex(aVertex, Dummy);
end;

function TGSimpleGraph.AddVertices(const aVertices: TVertexArray): SizeInt;
var
  v: TVertex;
begin
  Result := VertexCount;
  for v in aVertices do
    AddVertex(v);
  Result := VertexCount - Result;
end;

procedure TGSimpleGraph.RemoveVertex(constref aVertex: TVertex);
begin
  RemoveVertexI(IndexOf(aVertex));
end;

procedure TGSimpleGraph.RemoveVertexI(aIndex: SizeInt);
begin
  CheckIndexRange(aIndex);
  DoRemoveVertex(aIndex);
end;

function TGSimpleGraph.AddEdge(constref aSrc, aDst: TVertex; aData: TEdgeData): Boolean;
var
  SrcIdx, DstIdx: SizeInt;
begin
  AddVertex(aSrc, SrcIdx);
  AddVertex(aDst, DstIdx);
  Result := DoAddEdge(SrcIdx, DstIdx, aData);
end;

function TGSimpleGraph.AddEdge(constref aSrc, aDst: TVertex): Boolean;
begin
  Result := AddEdge(aSrc, aDst, Default(TEdgeData));
end;

function TGSimpleGraph.AddEdgeI(aSrc, aDst: SizeInt; aData: TEdgeData): Boolean;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  Result := DoAddEdge(aSrc, aDst, aData);
end;

function TGSimpleGraph.AddEdgeI(aSrc, aDst: SizeInt): Boolean;
begin
  Result := AddEdgeI(aSrc, aDst, Default(TEdgeData));
end;

function TGSimpleGraph.RemoveEdge(constref aSrc, aDst: TVertex): Boolean;
begin
  Result := RemoveEdgeI(IndexOf(aSrc), IndexOf(aDst));
end;

function TGSimpleGraph.RemoveEdgeI(aSrc, aDst: SizeInt): Boolean;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  Result := DoRemoveEdge(aSrc, aDst);
end;

function TGSimpleGraph.Degree(constref aVertex: TVertex): SizeInt;
begin
  Result := DegreeI(IndexOf(aVertex));
end;

function TGSimpleGraph.DegreeI(aIndex: SizeInt): SizeInt;
begin
  CheckIndexRange(aIndex);
  Result := FNodeList[aIndex].AdjList.Count;
end;

function TGSimpleGraph.Isolated(constref aVertex: TVertex): Boolean;
begin
  Result := Degree(aVertex) = 0;
end;

function TGSimpleGraph.IsolatedI(aIndex: SizeInt): Boolean;
begin
  Result := DegreeI(aIndex) = 0;
end;

function TGSimpleGraph.DistinctEdges: TDistinctEdges;
begin
  Result.FGraph := Self;
end;

function TGSimpleGraph.ComplementMatrix: TAdjacencyMatrix;
var
  m: TSquareBitMatrix;
  s, d: SizeInt;
begin
  if IsEmpty then
    exit(Default(TAdjacencyMatrix));
  m := TSquareBitMatrix.Create(VertexCount);
  for s := 0 to Pred(VertexCount) do
    for d := 0 to Pred(VertexCount) do
      if (s <> d) and not FNodeList[s].AdjList.Contains(d) then
        m[s, d] := True;
  Result := TAdjacencyMatrix.Create(m);
end;

function TGSimpleGraph.LocalClustering(constref aVertex: TVertex): ValReal;
begin
  Result := LocalClusteringI(IndexOf(aVertex));
end;

function TGSimpleGraph.LocalClusteringI(aIndex: SizeInt): Double;
var
  I, J, Counter, d: SizeInt;
  pList: PAdjList;
begin
  CheckIndexRange(aIndex);
  d := DegreeI(aIndex);
  if d <= 1 then
    exit(0.0);
  Counter := 0;
  for I in AdjVerticesI(aIndex) do
    begin
      pList := AdjLists[I];
      for J in AdjVerticesI(aIndex) do
        if I <> J then
          Counter += Ord(pList^.Contains(J));
    end;
  Result := Double(Counter) / (Double(d) * Double(Pred(d)));
end;

function TGSimpleGraph.EnsureConnected(aOnAddEdge: TOnAddEdge): SizeInt;
begin
  Result := 0;
  if VertexCount < 2 then
    exit;
  if SeparateCount < 2 then
    exit;
  Result := MakeConnected(aOnAddEdge);
end;

function TGSimpleGraph.PathExists(constref aSrc, aDst: TVertex): Boolean;
begin
  Result := PathExistsI(IndexOf(aSrc), IndexOf(aDst));
end;

function TGSimpleGraph.PathExistsI(aSrc, aDst: SizeInt): Boolean;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    exit(True);
  if SeparateCount > 1 then
    Result := SeparateTag(aSrc) = SeparateTag(aDst)
  else
    Result := True;
end;

function TGSimpleGraph.SeparatePop(constref aVertex: TVertex): SizeInt;
begin
  Result := SeparatePopI(IndexOf(aVertex));
end;

function TGSimpleGraph.SeparatePopI(aIndex: SizeInt): SizeInt;
begin
  CheckIndexRange(aIndex);
  if SeparateCount > 1 then
    Result := CountPop(SeparateTag(aIndex))
  else
    Result := VertexCount;
end;

function TGSimpleGraph.GetSeparate(constref aVertex: TVertex): TIntArray;
begin
  Result := GetSeparateI(IndexOf(aVertex));
end;

function TGSimpleGraph.GetSeparateI(aIndex: SizeInt): TIntArray;
var
  I, J, Tag: SizeInt;
begin
  CheckIndexRange(aIndex);
  if SeparateCount > 1 then
    begin
      Result{%H-}.Length := VertexCount;
      Tag := SeparateTag(aIndex);
      J := 0;
      for I := 0 to Pred(VertexCount) do
        if SeparateTag(I) = Tag then
          begin
            Result[J] := I;
            Inc(J);
          end;
      Result.Length := J;
    end
  else
    Result := CreateIntArrayRange;
end;

function TGSimpleGraph.FindSeparates: TIntVectorArray;
var
  Tags: TIntArray;
  CurrIndex, CurrTag, I: SizeInt;
begin
  if IsEmpty then
    exit(nil);
  Tags := CreateIntArray;
  CurrIndex := NULL_INDEX;
  System.SetLength(Result, SeparateCount);
  for I := 0 to Pred(VertexCount) do
    begin
      CurrTag := SeparateTag(I);
      if Tags[CurrTag] = NULL_INDEX then
        begin
          Inc(CurrIndex);
          Tags[CurrTag] := CurrIndex;
        end;
      Result[Tags[CurrTag]].Add(I);
    end;
end;

function TGSimpleGraph.IsTree: Boolean;
begin
  Result := (EdgeCount = Pred(VertexCount)) and Connected;
end;

function TGSimpleGraph.IsStar(out aHub: SizeInt): Boolean;
var
  I, d: SizeInt;
begin
  if (VertexCount < 4) or not IsTree then
    exit(False);
  aHub := NULL_INDEX;
  for I := 0 to Pred(VertexCount) do
    begin
      d := AdjLists[I]^.Count;
      if d = 1 then
        continue;
      if d <> Pred(VertexCount) then
        exit(False);
      aHub := I;
    end;
  Result := True;
end;

function TGSimpleGraph.IsCycle: Boolean;
var
  d: SizeInt;
begin
  if (VertexCount = EdgeCount) and Connected and IsRegular(d) then
    Result := d = 2
  else
    Result := False;
end;

function TGSimpleGraph.IsWheel(out aHub: SizeInt): Boolean;
var
  I, d: SizeInt;
begin
  aHub := NULL_INDEX;
  if (VertexCount >= 4) and (EdgeCount = Pred(VertexCount) shl 1) and Connected then
    begin
      for I := 0 to Pred(VertexCount) do
        begin
          d := AdjLists[I]^.Count;
          if d = 3 then
            continue;
          if d <> Pred(VertexCount) then
            exit(False);
          aHub := I;
        end;
      if aHub = NULL_INDEX then
        aHub := 0;
      Result := True;
    end
  else
    Result := False;
end;

function TGSimpleGraph.IsComplete: Boolean;
begin
  if Connected then
    Result := (EdgeCount shl 1) div VertexCount = Pred(VertexCount)
  else
    Result := False;
end;

function TGSimpleGraph.IsRegular(out aDegree: SizeInt): Boolean;
var
  I: SizeInt;
begin
  aDegree := NULL_INDEX;
  if NonEmpty then
    begin
      aDegree := AdjLists[0]^.Count;
      for I := 1 to Pred(VertexCount) do
        if AdjLists[I]^.Count <> aDegree then
          begin
            aDegree := NULL_INDEX;
            exit(False);
          end;
    end;
  Result := True;
end;

function TGSimpleGraph.CyclomaticNumber: SizeInt;
begin
  Result := EdgeCount - VertexCount + SeparateCount;
end;

function TGSimpleGraph.ContainsCycle(constref aVertex: TVertex; out aCycle: TIntArray): Boolean;
begin
  Result := ContainsCycleI(IndexOf(aVertex), aCycle);
end;

function TGSimpleGraph.ContainsCycleI(aIndex: SizeInt; out aCycle: TIntArray): Boolean;
begin
  CheckIndexRange(aIndex);
  if VertexCount < 3 then
    exit(False);
  if ConnectedValid and IsTree then
    exit(False);
  Result := CycleExists(aIndex, aCycle);
end;

function TGSimpleGraph.ContainsEulerianPath(out aFirstOdd: SizeInt): Boolean;
var
  Comps: TIntVectorArray;
  I, Cand, OddCount: SizeInt;
begin
  aFirstOdd := NULL_INDEX;
  if VertexCount < 2 then
    exit(False);
  Comps := FindSeparates;
  Cand := NULL_INDEX;
  for I := 0 to System.High(Comps) do
    if Comps[I].Count > 1 then
      if Cand = NULL_INDEX then
        Cand := I
      else
        exit(False);
  if Cand = NULL_INDEX then
    exit(False);
  OddCount := 0;
  for I in Comps[Cand] do
    if Odd(AdjLists[I]^.Count) then
      begin
        Inc(OddCount);
        if OddCount > 2 then
          begin
            aFirstOdd := NULL_INDEX;
            exit(False);
          end;
        if aFirstOdd = NULL_INDEX then
          aFirstOdd := I;
      end;
  Result := True;
end;

function TGSimpleGraph.ContainsEulerianCycle: Boolean;
var
  Comps: TIntVectorArray;
  I, Cand: SizeInt;
begin
  if VertexCount < 3 then
    exit(False);
  Comps := FindSeparates;
  Cand := NULL_INDEX;
  for I := 0 to System.High(Comps) do
    if Comps[I].Count > 1 then
      if Cand = NULL_INDEX then
        Cand := I
      else
        exit(False);
  if Cand = NULL_INDEX then
    exit(False);
  for I in Comps[Cand] do
    if Odd(AdjLists[I]^.Count) then
      exit(False);
  Result := True;
end;

function TGSimpleGraph.FindEulerianCycle: TIntArray;
var
  g: TSkeleton;
  Stack: TIntStack;
  s, d: SizeInt;
begin
  Result := nil;
  if not ContainsEulerianCycle then
    exit;
  g := CreateSkeleton;
  s := 0;
  while g.Degree[s] = 0 do
    Inc(s);
  {%H-}Stack.Push(s);
  while g[s]^.FindFirst(d) do
    begin
      g.RemoveEdge(s, d);
      Stack.Push(d);
      s := d;
    end;
  Result := Stack.ToArray;
end;

function TGSimpleGraph.FindEulerianPath: TIntArray;
var
  g: TSkeleton;
  Stack, Path: TIntStack;
  s, d: SizeInt;
begin
  Result := nil;
  if not ContainsEulerianPath(s) then
    exit;
  g := CreateSkeleton;
  if s = NULL_INDEX then
    begin
      s := 0;
      while g.Degree[s] = 0 do
        Inc(s);
    end;
  {%H-}Stack.Push(s);
  while Stack.TryPeek(s) do
    if g[s]^.FindFirst(d) then
      begin
        g.RemoveEdge(s, d);
        Stack.Push(d);
      end
    else
      {%H-}Path.Push(Stack.Pop{%H-});
  Result := Path.ToArray;
end;

function TGSimpleGraph.FindFundamentalCycles: TIntArrayVector;
begin
  Result := Default(TIntArrayVector);
  if IsTree then
    exit;
  SearchForFundamentalsCycles(Result);
  if Result.Count <> CyclomaticNumber then
    raise EGraphError.Create(SEInternalDataInconsist);
  TIntArrayVectorHelper.Sort(Result, @CmpIntArrayLen);
end;

function TGSimpleGraph.ContainsCutVertex(constref aVertex: TVertex): Boolean;
begin
  Result := ContainsCutVertexI(IndexOf(aVertex));
end;

function TGSimpleGraph.ContainsCutVertexI(aIndex: SizeInt): Boolean;
begin
  CheckIndexRange(aIndex);
  if VertexCount < 3 then
    exit(False);
  Result := CutVertexExists(aIndex);
end;

function TGSimpleGraph.FindCutVertices(constref aVertex: TVertex): TIntArray;
begin
  Result := FindCutVerticesI(IndexOf(aVertex));
end;

function TGSimpleGraph.FindCutVerticesI(aIndex: SizeInt): TIntArray;
var
  v: TIntHashSet;
begin
  CheckIndexRange(aIndex);
  if VertexCount > 2 then
    begin
      SearchForCutVertices(aIndex, v{%H-});
      Result := v.ToArray;
    end
  else
    Result := nil;
end;

function TGSimpleGraph.RemoveCutVertices(constref aVertex: TVertex; aOnAddEdge: TOnAddEdge): SizeInt;
begin
  Result := RemoveCutVerticesI(IndexOf(aVertex), aOnAddEdge);
end;

function TGSimpleGraph.RemoveCutVerticesI(aIndex: SizeInt; aOnAddEdge: TOnAddEdge): SizeInt;
var
  NewEdges: TIntEdgeVector;
  e: TIntEdge;
  d: TEdgeData;
begin
  Result := 0;
  CheckIndexRange(aIndex);
  if VertexCount < 3 then
    exit;
  SearchForBiconnect(aIndex, NewEdges{%H-});
  d := Default(TEdgeData);
  for e in NewEdges do
    begin
      if Assigned(aOnAddEdge) then
        aOnAddEdge(FNodeList[e.Source].Vertex, FNodeList[e.Destination].Vertex, @d);
      Result += Ord(AddEdgeI(e.Source, e.Destination, d));
    end;
end;

function TGSimpleGraph.ContainsBridge: Boolean;
begin
  if VertexCount > 1 then
    Result := BridgeExists
  else
    Result := False;
end;

function TGSimpleGraph.FindBridges: TIntEdgeArray;
var
  v: TIntEdgeVector;
begin
  v := Default(TIntEdgeVector);
  if VertexCount > 1 then
    SearchForBridges(v);
  Result := v.ToArray;
end;

function TGSimpleGraph.IsBiconnected: Boolean;
begin
  if Connected then
    Result := not ContainsCutVertexI(0)
  else
    Result := False;
end;

function TGSimpleGraph.FindBicomponents(constref aVertex: TVertex): TEdgeArrayVector;
begin
  Result := FindBicomponentsI(IndexOf(aVertex));
end;

function TGSimpleGraph.FindBicomponentsI(aIndex: SizeInt): TEdgeArrayVector;
begin
  Result := Default(TEdgeArrayVector);
  CheckIndexRange(aIndex);
  if VertexCount > 2 then
    SearchForBicomponent(aIndex, Result)
  else
    if (VertexCount = 2) and ContainsEdgeI(0, 1) then
      Result.Add([TIntEdge.Create(0, 1)]);
end;

function TGSimpleGraph.EnsureBiconnected(aOnAddEdge: TOnAddEdge): SizeInt;
var
  NewEdges: TIntEdgeVector;
  e: TIntEdge;
  d: TEdgeData;
begin
  Result := EnsureConnected(aOnAddEdge);
  if VertexCount < 3 then
    exit;
  SearchForBiconnect(0, NewEdges{%H-});
  d := Default(TEdgeData);
  for e in NewEdges do
    begin
      if Assigned(aOnAddEdge) then
        aOnAddEdge(Items[e.Source], Items[e.Destination], @d);
      Result += Ord(AddEdgeI(e.Source, e.Destination, d));
    end;
end;

function TGSimpleGraph.FindMerics(out aRadius, aDiameter: SizeInt): Boolean;
var
  Queue, Dist: TIntArray;
  VertCount, I, Ecc, J, d, qHead, qTail: SizeInt;
  p: PAdjItem;
begin
  if not Connected then
    exit(False);
  VertCount := VertexCount;
  aRadius := VertCount;
  aDiameter := 0;
  Queue.Length := VertCount;
  Dist.Length := VertCount;
  for I := 0 to Pred(VertCount) do
    begin
      System.FillChar(Pointer(Dist)^, VertCount * SizeOf(SizeInt), $ff);
      Dist[I] := 0;
      Ecc := 0;
      qHead := 0;
      qTail := 0;
      Queue[qTail] := I;
      Inc(qTail);
      while qHead < qTail do
        begin
          J := Queue[qHead];
          Inc(qHead);
          for p in AdjLists[J]^ do
            if Dist[p^.Key] = NULL_INDEX then
              begin
                Queue[qTail] := p^.Key;
                Inc(qTail);
                d := Succ(Dist[J]);
                if Ecc < d then
                  Ecc := d;
                Dist[p^.Key] := d;
              end;
        end;
      if Ecc < aRadius then
        aRadius := Ecc;
      if Ecc > aDiameter then
        aDiameter := Ecc;
    end;
  Result := True;
end;

function TGSimpleGraph.FindCenter(out aCenter: TIntArray): Boolean;
var
  Queue, Dist, Eccs: TIntArray;
  VertCount, Radius, I, Ecc, J, d, qHead, qTail: SizeInt;
  p: PAdjItem;
begin
  if not Connected then
    exit(False);
  VertCount := VertexCount;
  Radius := VertCount;
  Queue.Length := VertCount;
  Dist.Length := VertCount;
  Eccs.Length := VertCount;
  for I := 0 to Pred(VertCount) do
    begin
      System.FillChar(Pointer(Dist)^, VertCount * SizeOf(SizeInt), $ff);
      Dist[I] := 0;
      Ecc := 0;
      qHead := 0;
      qTail := 0;
      Queue[qTail] := I;
      Inc(qTail);
      while qHead < qTail do
        begin
          J := Queue[qHead];
          Inc(qHead);
          for p in AdjLists[J]^ do
            if Dist[p^.Key] = NULL_INDEX then
              begin
                Queue[qTail] := p^.Key;
                Inc(qTail);
                d := Succ(Dist[J]);
                if Ecc < d then
                  Ecc := d;
                Dist[p^.Key] := d;
              end;
        end;
      Eccs[I] := Ecc;
      if Ecc < Radius then
        Radius := Ecc;
    end;
  aCenter.Length := VertCount;
  J := 0;
  for I := 0 to Pred(VertCount) do
    if Eccs[I] = Radius then
      begin
        aCenter[J] := I;
        Inc(J);
      end;
  aCenter.Length := J;
  Result := True;
end;

function TGSimpleGraph.MinCut: SizeInt;
var
  Helper: TNiMinCut;
begin
  if not Connected or (VertexCount < 2) then
    exit(0);
  if VertexCount = 2 then
    exit(1);
  Result := Helper.GetMinCut(Self);
end;

function TGSimpleGraph.MinCut(out aCut: TCut): SizeInt;
var
  Helper: TNiMinCut;
  Cut: TIntSet;
  B: TBoolVector;
  I: SizeInt;
begin
  if not Connected or (VertexCount < 2) then
    exit(0);
  if VertexCount = 2 then
    begin
      aCut.A := [0];
      aCut.B := [1];
      exit(1);
    end;
  Result := Helper.GetMinCut(Self, Cut);
  B.InitRange(VertexCount);
  for I in Cut do
    B[I] := False;
  aCut.A := Cut.ToArray;
  aCut.B := B.ToArray;
end;

function TGSimpleGraph.MinCutCrossing: TIntEdgeArray;
var
  Helper: TNiMinCut;
  Cut: TIntSet;
  Left, Right: TBoolVector;
  I, J: SizeInt;
  p: PAdjItem;
begin
  if not Connected or (VertexCount < 2) then
    exit([]);
  if VertexCount = 2 then
    exit([TIntEdge.Create(0, 1)]);
  System.SetLength(Result, Helper.GetMinCut(Self, Cut));
  if Cut.Count <= VertexCount shr 1 then
    begin
      Left.Size := VertexCount;
      Right.InitRange(VertexCount);
      for I in Cut do
        begin
          Left[I] := True;
          Right[I] := False;
        end;
    end
  else
    begin
      Right.Size := VertexCount;
      Left.InitRange(VertexCount);
      for I in Cut do
        begin
          Right[I] := True;
          Left[I] := False;
        end;
    end;
  J := 0;
  for I in Left do
    for p in AdjLists[I]^ do
      if Right[p^.Destination] then
        begin
          if I < p^.Destination then
            Result[J] := TIntEdge.Create(I, p^.Destination)
          else
            Result[J] := TIntEdge.Create(p^.Destination, I);
          Inc(J);
        end;
end;

function TGSimpleGraph.FindMaxBipartiteMatchingHK(out aMatch: TIntEdgeArray): Boolean;
var
  Helper: THKMatch;
  w, g: TIntArray;
begin
  if not IsBipartite(w, g) then
    exit(False);
  aMatch := Helper.MaxMatching(Self, w, g);
  Result := True;
end;

function TGSimpleGraph.MaxBipartiteMatchingHK(const aWhites, aGrays: TIntArray): TIntEdgeArray;
var
  Helper: THKMatch;
begin
  Result := Helper.MaxMatching(Self, aWhites, aGrays);
end;

function TGSimpleGraph.FindMaxBipartiteMatchingBfs(out aMatch: TIntEdgeArray): Boolean;
var
  Helper: TBfsMatch;
  w, g: TIntArray;
begin
  if not IsBipartite(w, g) then
    exit(False);
  aMatch := Helper.MaxMatching(Self, w, g);
  Result := True;
end;

function TGSimpleGraph.MaxBipartiteMatchingBfs(const aWhites, aGrays: TIntArray): TIntEdgeArray;
var
  Helper: TBfsMatch;
begin
  Result := Helper.MaxMatching(Self, aWhites, aGrays);
end;

function TGSimpleGraph.IsMaxBipartiteMatching(const aMatch: TIntEdgeArray): Boolean;
var
  w, g: TIntArray;
  WhiteFree, GrayFree,
  WhiteCover, GrayCover: TIntHashSet;
  e: TIntEdge;
  I, J: SizeInt;
begin
  if System.Length(aMatch) = 0 then
    exit(False);
  if not IsBipartite(w, g) then
    exit(False);
  WhiteFree.AddAll(w);
  GrayFree.AddAll(g);
  w := nil;
  g := nil;
  for e in aMatch do
    begin
      if SizeUInt(e.Source) >= SizeUInt(VertexCount) then
        exit(False);
      if SizeUInt(e.Destination) >= SizeUInt(VertexCount) then
        exit(False);
      if e.Source = e.Destination then
        exit(False);
      if not AdjLists[e.Source]^.Contains(e.Destination) then
        exit(False);
      if WhiteFree.Remove(e.Source) then
        begin
          if not GrayFree.Remove(e.Destination) then  //contains adjacent edges -> not matching
            exit(False);
          WhiteCover.Add(e.Source);
          GrayCover.Add(e.Destination)
        end
      else
        begin
          if not WhiteFree.Remove(e.Destination)then //contains adjacent edges -> not matching
            exit(False);
          if not GrayFree.Remove(e.Source) then      //contains adjacent edges -> not matching
            exit(False);
          WhiteCover.Add(e.Destination);
          GrayCover.Add(e.Source);
        end;
    end;
  for I in WhiteFree do
    for J in AdjVerticesI(I) do
      if GrayFree.Contains(J) then  // is not maximal
        exit(False);
  Result := True;
end;

function TGSimpleGraph.GreedyMaxMatching: TIntEdgeArray;
begin
  if VertexCount < 2 then
    exit(nil);
  if (VertexCount = 2) and Connected then
    exit([TIntEdge.Create(0, 1)]);
  Result := GreedyMatching2;
end;

function TGSimpleGraph.FindMaxMatchingEd: TIntEdgeArray;
var
  Helper: TEdMatch;
begin
  if VertexCount < 2 then
    exit(nil);
  if not FindMaxBipartiteMatchingHK(Result) then
    Result := Helper.MaxMatching(Self);
end;

function TGSimpleGraph.FindMaxMatchingPC: TIntEdgeArray;
var
  Helper: TPcMatch;
begin
  if VertexCount < 2 then
    exit(nil);
  if not FindMaxBipartiteMatchingHK(Result) then
    Result := Helper.MaxMatching(Self);
end;

function TGSimpleGraph.FindMaxMatchingMV: TIntEdgeArray;
begin
  if VertexCount < 2 then
    exit(nil);
  if not FindMaxBipartiteMatchingHK(Result) then
    Result := GetMvMatching;
end;

procedure TGSimpleGraph.ListIndependentSets(aOnFindSet: TOnFindSet);
begin
  if IsEmpty then
    exit;
  if aOnFindSet = nil then
    raise EGraphError.Create(SECallbackMissed);
  if VertexCount > TBits256.BITNESS then
    ListIsBP(aOnFindSet)
  else
    ListIsBP256(aOnFindSet)
end;

function TGSimpleGraph.MaxIndependentSet(out aExactSolution: Boolean; aTimeOut: Integer): TIntArray;
var
  w, g: TIntArray;
begin
  if IsEmpty then
    exit(nil);
  if VertexCount < 2 then
    exit([0]);
  if IsBipartite(w, g) then
    Result := GetMaxIsBipartite(w, g)
  else
    if VertexCount > TBits256.BITNESS then
      Result := GetMaxIsBP(aTimeOut, aExactSolution)
    else
      Result := GetMaxIsBP256(aTimeOut, aExactSolution);
end;

function TGSimpleGraph.GreedyMIS: TIntArray;
begin
  if IsEmpty then
    exit(nil);
  if VertexCount = 1 then
    exit([0]);
  if VertexCount > COMMON_BP_CUTOFF then
    Result := GetGreedyMis
  else
    Result := GetGreedyMisBP;
end;

function TGSimpleGraph.IsMaxIndependentSet(const aTestSet: TIntArray): Boolean;
var
  TestIS, Remain: TBoolVector;
  I, J: SizeInt;
  AdjFound: Boolean;
begin
  if System.Length(aTestSet) = 0 then
    exit(False);
  TestIS.Size := VertexCount;
  for I in aTestSet do
    begin
      if SizeUInt(I) >= SizeUInt(VertexCount) then //contains garbage
        exit(False);
      if TestIS[I] then  //contains duplicates -> is not set
        exit(False);
      TestIS[I] := True;
    end;
  for I in aTestSet do
    for J in aTestSet do
      if (I <> J) and AdjacentI(I, J) then //contains adjacent vertices -> is not independent
        exit(False);
  Remain.InitRange(VertexCount);
  Remain.Subtract(TestIS);
  Finalize(TestIS);
  for I in Remain do
    begin
      AdjFound := False;
      for J in aTestSet do
        if AdjacentI(I, J) then
          begin
            AdjFound := True;
            break;
          end;
      if not AdjFound then //I can be added to aTestSet -> aTestSet is not maximal
        exit(False);
    end;
  Result := True;
end;

function TGSimpleGraph.MinDominatingSet(out aExactSolution: Boolean; aTimeOut: Integer): TIntArray;
begin
  if not Connected then
    raise EGraphError.Create(SEMethodNotApplicable); //????
  if VertexCount < 3 then
    exit([0]);
  if VertexCount > COMMON_BP_CUTOFF then
    Result := GetMds(aTimeOut, aExactSolution)
  else
    if VertexCount > TBits256.BITNESS then
      Result := GetMdsBP(aTimeOut, aExactSolution)
    else
      Result := GetMdsBP256(aTimeOut, aExactSolution);
end;

function TGSimpleGraph.GreedyMDS: TIntArray;
begin
  if not Connected then
    raise EGraphError.Create(SEMethodNotApplicable);
  if VertexCount < 3 then
    exit([0]);
  if VertexCount > COMMON_BP_CUTOFF then
    Result := GetGreedyMinIs
  else
    Result := GetGreedyMinIsBP;
end;

function TGSimpleGraph.IsMinDominatingSet(const aTestSet: TIntArray): Boolean;
var
  TestMds, Remain: TBoolVector;
  I, J, K: SizeInt;
  AdjFound: Boolean;
begin
  if not Connected then
    exit(False);
  if System.Length(aTestSet) = 0 then
    exit(False);
  TestMds.Size := VertexCount;
  for I in aTestSet do
    begin
      if SizeUInt(I) >= SizeUInt(VertexCount) then //contains garbage
        exit(False);
      if TestMds[I] then   //contains duplicates -> is not set
        exit(False);
      TestMds[I] := True;
    end;
  Remain.InitRange(VertexCount);
  Remain.Subtract(TestMds);
  Finalize(TestMds);
  for I in Remain do
    begin
      AdjFound := False;
      for J in aTestSet do
        if AdjacentI(I, J) then
          begin
            AdjFound := True;
            break;
          end;
      if not AdjFound then //is not dominating set
        exit(False);
    end;

  for I in aTestSet do
    begin
      AdjFound := False;
      for J in aTestSet do
        if (I <> J) and AdjacentI(I, J) then
          begin
            AdjFound := True;
            break;
          end;
      if AdjFound then //test aTestSet without I
        begin
          for K in Remain do
            begin
              AdjFound := False;
              for J in aTestSet do
                if (K <> J) and (J <> I) and AdjacentI(K, J) then
                  begin
                    AdjFound := True;
                    break;
                  end;
              if not AdjFound then //exists vertex nonadjacent with aTestSet without I
                break;
            end;
          if AdjFound then  //is not minimal
            exit(False);
        end;
    end;
  Result := True;
end;

procedure TGSimpleGraph.ListMaxCliques(aOnFindClique: TOnFindSet);
begin
  if IsEmpty then
    exit;
  if aOnFindClique = nil then
    raise EGraphError.Create(SECallbackMissed);
  if (VertexCount > LISTCLIQUES_BP_CUTOFF) or (Density <= MAXCLIQUE_BP_DENSITY_CUTOFF) then
    ListCliques(aOnFindClique)
  else
    if VertexCount > TBits256.BITNESS then
      ListCliquesBP(aOnFindClique)
    else
      ListCliquesBP256(aOnFindClique);
end;

function TGSimpleGraph.MaxClique(out aExactSolution: Boolean; aTimeOut: Integer): TIntArray;
begin
  if IsEmpty then
    exit(nil);
  if (VertexCount >= COMMON_BP_CUTOFF) or (Density <= MAXCLIQUE_BP_DENSITY_CUTOFF) then
    Result := GetMaxClique(aTimeOut, aExactSolution)
  else
    if VertexCount > TBits256.BITNESS then
      Result := GetMaxCliqueBP(aTimeOut, aExactSolution)
    else
      Result := GetMaxCliqueBP256(aTimeOut, aExactSolution);
end;

function TGSimpleGraph.GreedyMaxClique: TIntArray;
var
  Cand, Stack, Q: TIntSet;
  I, J: SizeInt;
begin
  if IsEmpty then
    exit(nil);
  Cand.AssignArray(SortNodesByWidth(soAsc));
  while Cand.NonEmpty do
    begin
      I := Cand.Pop;
      {%H-}Stack.Push(I);
      for J in Cand do
        if AdjLists[I]^.Contains(J) then
          {%H-}Q.Push(J);
      Cand.Assign(Q);
      Q.MakeEmpty;
    end;
  Result := Stack.ToArray;
end;

function TGSimpleGraph.IsMaxClique(const aTestClique: TIntArray): Boolean;
var
  TestClique, Remain: TBoolVector;
  I, J: SizeInt;
  AdjFound: Boolean;
begin
  if System.Length(aTestClique) = 0 then
    exit(False);
  TestClique.Size := VertexCount;
  for I in aTestClique do
    begin
      if SizeUInt(I) >= SizeUInt(VertexCount) then //contains garbage
        exit(False);
      if TestClique[I] then //contains duplicates -> is not set
        exit(False);
      TestClique[I] := True;
    end;
  for I in aTestClique do
    for J in aTestClique do
      if (I <> J) and not AdjacentI(I, J) then //contains nonadjacent vertices -> is not clique
        exit(False);
  Remain.InitRange(VertexCount);
  Remain.Subtract(TestClique);
  Finalize(TestClique);
  for I in Remain do
    begin
      AdjFound := True;
      for J in aTestClique do
        if not AdjacentI(I, J) then
          begin
            AdjFound := False;
            break;
          end;
      if AdjFound then // I can be added to clique -> clique is not maximal
        exit(False);
    end;
  Result := True;
end;

function TGSimpleGraph.VertexColoring(out aColors: TIntArray; out aExact: Boolean; aTimeOut: Integer): SizeInt;
begin
  //todo: planar graphs, chordal graphs ?
  if ColorTrivial(Result, aColors) then
    aExact := True
  else
    if Connected then
      Result := ColorConnected(aTimeOut, aColors, aExact)
    else
      Result := ColorDisconnected(aTimeOut, aColors, aExact);
end;

function TGSimpleGraph.IsKColorable(aK: SizeInt; out aColors: TIntArray; aTimeOut: Integer): TTriLean;
var
  K: SizeInt;
begin
  if aK <= 0 then
    exit(tlFalse);
  K := GreedyVertexColoringRlf(aColors);
  if K <= aK then
    exit(tlTrue);
  aColors := nil;
  if Connected then
    Result := ColorableConnected(aK, aTimeOut, aColors)
  else
    Result := ColorableDisconnected(aK, aTimeOut, aColors);
end;

function TGSimpleGraph.FindCompleteColoring(aMaxColor: SizeInt; var aColors: TIntArray; aTimeOut: Integer): Boolean;
var
  Helper: TExactColor;
  I: SizeInt;
begin
  if aMaxColor <= 0 then
    exit(False);
  if aColors.Length <> VertexCount then
    exit(False);
  for I in aColors do
    if (I < 0) or (I > aMaxColor) then
      exit(False);
  Result := Helper.Complete(Self, aMaxColor, aTimeOut, aColors);
end;

function TGSimpleGraph.GreedyVertexColoringRlf(out aColors: TIntArray): SizeInt;
var
  I: SizeInt;
begin
  if IsEmpty then
    begin
      aColors := nil;
      exit(0);
    end;
  if IsComplete then
    begin
      aColors.Length := VertexCount;
      for I := 0 to Pred(VertexCount) do
        aColors[I] := Succ(I);
      exit(VertexCount);
    end;
  Result := GreedyColorRlf(aColors);
end;

function TGSimpleGraph.GreedyVertexColoring(out aColors: TIntArray): SizeInt;
begin
  if not ColorTrivial(Result, aColors) then
    Result := GreedyColor(aColors);
end;

function TGSimpleGraph.IsProperVertexColoring(const aTestColors: TIntArray): Boolean;
var
  sCol, dCol: SizeInt;
  e: TEdge;
begin
  if IsEmpty then
    exit(aTestColors = nil);
  if aTestColors.Length <> VertexCount then
    exit(False);
  for e in DistinctEdges do
    begin
      sCol := aTestColors[e.Source];
      dCol := aTestColors[e.Destination];
      if (sCol < 1) or (sCol > VertexCount) or (dCol < 1) or (dCol > VertexCount) or (sCol = dCol) then
        exit(False);
    end;
  Result := True;
end;

function TGSimpleGraph.FindHamiltonCycles(constref aSource: TVertex; aCount: SizeInt; out aCycles: TIntArrayVector;
  aTimeOut: Integer): Boolean;
begin
  Result := FindHamiltonCyclesI(IndexOf(aSource), aCount, aCycles, aTimeOut);
end;

function TGSimpleGraph.FindHamiltonCyclesI(aSourceIdx, aCount: SizeInt; out aCycles: TIntArrayVector;
  aTimeOut: Integer): Boolean;
var
  Helper: THamiltonian;
  I: SizeInt;
begin
  CheckIndexRange(aSourceIdx);
  {%H-}aCycles.Clear;
  if not Connected or (VertexCount < 2) then
    exit(False);
  if VertexCount = 2 then
    begin
      if aSourceIdx = 0 then
        aCycles.Add([0, 1, 0])
      else
        aCycles.Add([1, 0, 1]);
      exit(True);
    end;
  for I := 0 to Pred(VertexCount) do
    if AdjLists[I]^.Count < 2 then
      exit(False);
  Result := Helper.FindCycles(Self, aSourceIdx, aCount, aTimeOut, @aCycles);
end;

function TGSimpleGraph.IsHamiltonCycle(const aTestCycle: TIntArray; aSourceIdx: SizeInt): Boolean;
var
  VertSet: TBitVector;
  I, Curr, Next: SizeInt;
begin
  CheckIndexRange(aSourceIdx);
  if aTestCycle.Length <> Succ(VertexCount) then
    exit(False);
  if (aTestCycle[0] <> aSourceIdx) or (aTestCycle[VertexCount] <> aSourceIdx) then
    exit(False);
  VertSet.Size := VertexCount;
  Next := aSourceIdx;
  VertSet[aSourceIdx] := True;
  for I := 1 to Pred(VertexCount) do
    begin
      Curr := Next;
      Next := aTestCycle[I];
      if SizeUInt(Next) >= SizeUInt(VertexCount) then
        exit(False);
      if VertSet[Next] then
        exit(False);
      VertSet[Next] := True;
      if not AdjLists[Curr]^.Contains(Next) then
        exit(False);
    end;
  Result := True;
end;

function TGSimpleGraph.FindHamiltonPaths(constref aSrc, aDst: TVertex; aCount: SizeInt; out
  aPaths: TIntArrayVector; aTimeOut: Integer): Boolean;
begin
  Result := FindHamiltonPathsI(IndexOf(aSrc), IndexOf(aDst), aCount, aPaths, aTimeOut);
end;

function TGSimpleGraph.FindHamiltonPathsI(aSrcIdx, aDstIdx, aCount: SizeInt; out aPaths: TIntArrayVector;
  aTimeOut: Integer): Boolean;
var
  Helper: THamiltonian;
  I: SizeInt;
begin
  CheckIndexRange(aSrcIdx);
  CheckIndexRange(aDstIdx);
  {%H-}aPaths.Clear;
  if not Connected or (VertexCount < 2) then
    exit(False);
  for I := 0 to Pred(VertexCount) do
    if (I <> aSrcIdx) and (I <> aDstIdx) and (AdjLists[I]^.Count < 2) then
      exit(False);
  Result := Helper.FindPaths(Self, aSrcIdx, aDstIdx, aCount, aTimeOut, @aPaths);
end;

function TGSimpleGraph.IsHamiltonPath(const aTestPath: TIntArray; aSrcIdx, aDstIdx: SizeInt): Boolean;
var
  VertSet: TBitVector;
  I, Curr, Next: SizeInt;
begin
  CheckIndexRange(aSrcIdx);
  CheckIndexRange(aDstIdx);
  if aTestPath.Length <> VertexCount then
    exit(False);
  if aTestPath[0] <> aSrcIdx then
    exit(False);
  if aTestPath[Pred(VertexCount)] <> aDstIdx then
    exit(False);
  VertSet.Size := VertexCount;
  Next := aSrcIdx;
  VertSet[aSrcIdx] := True;
  for I := 1 to Pred(VertexCount) do
    begin
      Curr := Next;
      Next := aTestPath[I];
      if SizeUInt(Next) >= SizeUInt(VertexCount) then
        exit(False);
      if VertSet[Next] then
        exit(False);
      VertSet[Next] := True;
      if not AdjLists[Curr]^.Contains(Next) then
        exit(False);
    end;
  Result := True;
end;

{ TGChart }

procedure TGChart.ReadData(aStream: TStream; out aValue: TEmptyRec);
begin
  aStream.ReadBuffer(aValue{%H-}, SizeOf(aValue));
end;

procedure TGChart.WriteData(aStream: TStream; constref aValue: TEmptyRec);
begin
  aStream.WriteBuffer(aValue, SizeOf(aValue));
end;

constructor TGChart.Create;
begin
  inherited;
  OnStreamReadData := @ReadData;
  OnStreamWriteData := @WriteData;
end;

function TGChart.SeparateGraph(constref aVertex: TVertex): TGChart;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TGChart.SeparateGraphI(aIndex: SizeInt): TGChart;
begin
  Result := TGChart.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self);
end;

function TGChart.SubgraphFromVertexList(const aList: TIntArray): TGChart;
begin
  Result := TGChart.Create;
  Result.AssignVertexList(Self, aList);
end;

function TGChart.SubgraphFromTree(const aTree: TIntArray): TGChart;
begin
  Result := TGChart.Create;
  Result.AssignTree(Self, aTree);
end;

function TGChart.SubgraphFromEdges(const aEdges: TIntEdgeArray): TGChart;
begin
  Result := TGChart.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TGChart.Clone: TGChart;
begin
  Result := TGChart.Create;
  Result.AssignGraph(Self);
end;

{ TIntChart }

procedure TIntChart.WriteVertex(aStream: TStream; constref aValue: Integer);
begin
  aStream.WriteBuffer(NtoLE(aValue), SizeOf(aValue));
end;

procedure TIntChart.ReadVertex(aStream: TStream; out aValue: Integer);
begin
  aStream.ReadBuffer(aValue{%H-}, SizeOf(aValue));
  aValue := LEtoN(aValue);
end;

constructor TIntChart.Create;
begin
  inherited;
  OnStreamReadVertex := @ReadVertex;
  OnStreamWriteVertex := @WriteVertex;
end;

procedure TIntChart.LoadDIMACSAscii(const aFileName: string);
type
  TReaderRef = specialize TGAutoRef<TTextFileReader>;
var
  ReaderRef: TReaderRef;
  Reader: TTextFileReader;
  Line, ParseLine, Elem: string;
  I: SizeInt;
  CurrEdge: array[0..1] of SizeInt;
  Symb: AnsiChar;
begin
  Reader := ReaderRef;
  if not Reader.Open(aFileName) then
    raise EGraphError.CreateFmt(SEUnableOpenFileFmt, [aFileName]);
  Clear;
  for Line in Reader do
    begin
      ParseLine := Trim(Line);
      Symb := LowerCase(ParseLine)[1];
      case Symb of
        'c':
          begin
            Description.Add(System.Copy(ParseLine, 3, System.Length(ParseLine)));
            continue;
          end;
        'e':
          begin
            I := 0;
            for Elem in Line.SplitSB([' ']) do
              begin
                if LowerCase(Elem) = Symb then
                  continue;
                CurrEdge[I] := StrToInt(Elem);
                if I = 1 then
                  break;
                Inc(I);
              end;
            if I = 0 then
              begin
                Clear;
                raise EGraphError.Create(SEUnexpectEol);
              end;
            AddEdge(CurrEdge[0], CurrEdge[1]);
          end;
      end;
    end;
end;

function TIntChart.SeparateGraph(aVertex: Integer): TIntChart;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TIntChart.SeparateGraphI(aIndex: SizeInt): TIntChart;
begin
  Result := TIntChart.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self);
end;

function TIntChart.SubgraphFromVertexList(const aList: TIntArray): TIntChart;
begin
  Result := TIntChart.Create;
  Result.AssignVertexList(Self, aList);
end;

function TIntChart.SubgraphFromTree(const aTree: TIntArray): TIntChart;
begin
  Result := TIntChart.Create;
  Result.AssignTree(Self, aTree);
end;

function TIntChart.SubgraphFromEdges(const aEdges: TIntEdgeArray): TIntChart;
begin
  Result := TIntChart.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TIntChart.Clone: TIntChart;
begin
  Result := TIntChart.Create;
  Result.AssignGraph(Self);
end;

function TIntChart.AddVertexRange(aFrom, aTo: Integer): Integer;
var
  I: Integer;
begin
  Result := VertexCount;
  for I := aFrom to aTo do
    AddVertex(I);
  Result := VertexCount - Result;
end;

function TIntChart.AddEdges(const aVertexList: array of Integer): Integer;
var
  I, R: Integer;
begin
  Result := EdgeCount;
  R := System.High(aVertexList);
  I := 0;
  while I < R do
    begin
      AddEdge(aVertexList[I], aVertexList[Succ(I)]);
      I += 2;
    end;
  Result := EdgeCount - Result;
end;

{ TGraphDotWriter }

function TGraphDotWriter.Graph2Dot(aGraph: TGraph): utf8string;
var
  s: utf8string;
  I: SizeInt;
  e: TGraph.TEdge;
begin
  if aGraph.Title <> '' then
    s := '"' + aGraph.Title + '"'
  else
    s := 'Untitled';
  with TStringList.Create do
    try
      SkipLastLineBreak := True;
      WriteBOM := False;
      DefaultEncoding := TEncoding.UTF8;
      Add(FGraphMark + s + ' {');
      Add(DIRECTS[Direction]);
      if Assigned(OnStartWrite) then
        begin
          s := OnStartWrite(aGraph);
          Add(s);
        end;
      if Assigned(OnWriteVertex) then
        for I := 0 to Pred(aGraph.VertexCount) do
          begin
            s := OnWriteVertex(aGraph, I);
            Add(s);
          end;
        for e in (aGraph as TSimpleGraph).DistinctEdges do
          begin
            if Assigned(OnWriteEdge) then
              s := OnWriteEdge(aGraph, e)
            else
              s := DefaultWriteEdge(aGraph, e);
            Add(s);
          end;
      Add('}');
      Result := Text;
    finally
      Free;
    end;
end;

constructor TGraphDotWriter.Create;
begin
  FGraphMark := 'graph ';
  FEdgeMark := '--';
end;

{ TIntChartDotWriter }

function TIntChartDotWriter.DefaultWriteEdge(aGraph: TGraph; constref aEdge: TGraph.TEdge): utf8string;
begin
  Result := IntToStr(aGraph[aEdge.Source]) + FEdgeMark + IntToStr(aGraph[aEdge.Destination]) + ';';
end;

{ TStrChart }

procedure TStrChart.WriteVertex(aStream: TStream; constref aValue: string);
var
  Len: SizeInt;
  sLen: SmallInt;
begin
  Len := System.Length(aValue);
  if Len > High(SmallInt) then
    raise EGraphError.CreateFmt(SEStrLenExceedFmt, [Len]);
  sLen := Len;
  aStream.WriteBuffer(sLen, SizeOf(sLen));
  aStream.WriteBuffer(Pointer(aValue)^, Len);
end;

procedure TStrChart.ReadVertex(aStream: TStream; out aValue: string);
var
  Len: SmallInt;
begin
  aStream.ReadBuffer(Len{%H-}, SizeOf(Len));
  System.SetLength(aValue, Len);
  aStream.ReadBuffer(Pointer(aValue)^, Len);
end;

constructor TStrChart.Create;
begin
  inherited;
  OnStreamReadVertex := @ReadVertex;
  OnStreamWriteVertex := @WriteVertex;
end;

function TStrChart.SeparateGraph(const aVertex: string): TStrChart;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TStrChart.SeparateGraphI(aIndex: SizeInt): TStrChart;
begin
  Result := TStrChart.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self);
end;

function TStrChart.SubgraphFromVertexList(const aList: TIntArray): TStrChart;
begin
  Result := TStrChart.Create;
  Result.AssignVertexList(Self, aList);
end;

function TStrChart.SubgraphFromTree(const aTree: TIntArray): TStrChart;
begin
  Result := TStrChart.Create;
  Result.AssignTree(Self, aTree);
end;

function TStrChart.SubgraphFromEdges(const aEdges: TIntEdgeArray): TStrChart;
begin
  Result := TStrChart.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TStrChart.Clone: TStrChart;
begin
  Result := TStrChart.Create;
  Result.AssignGraph(Self);
end;

{ TStrChartDotWriter }

function TStrChartDotWriter.DefaultWriteEdge(aGraph: TGraph; constref aEdge: TGraph.TEdge): utf8string;
begin
  Result := '"' + aGraph[aEdge.Source] + '"' + FEdgeMark + '"' + aGraph[aEdge.Destination] + '";';
end;

{ TGWeightedGraph }

function TGWeightedGraph.CreateEdgeArray: TEdgeArray;
var
  I, J: SizeInt;
  p: PAdjItem;
begin
  System.SetLength(Result, EdgeCount);
  J := 0;
  for I := 0 to Pred(VertexCount) do
    for p in AdjLists[I]^ do
      if p^.Destination > I then
        begin
          Result[J] := TWeightEdge.Create(I, p^.Destination, p^.Data.Weight);
          Inc(J);
        end;
end;

class function TGWeightedGraph.InfWeight: TWeight;
begin
  Result := TWeight.INF_VALUE;
end;

class function TGWeightedGraph.NegInfWeight: TWeight;
begin
  Result := TWeight.NEGINF_VALUE;
end;

class function TGWeightedGraph.TotalWeight(const aEdges: TEdgeArray): TWeight;
var
  e: TWeightEdge;
begin
  Result := 0;
  for e in aEdges do
    Result += e.Weight;
end;

function TGWeightedGraph.ContainsNegWeightEdge: Boolean;
var
  e: TEdge;
begin
  for e in DistinctEdges do
    if e.Data.Weight < 0 then
      exit(True);
  Result := False;
end;

function TGWeightedGraph.ContainsNegCycle(constref aRoot: TVertex; out aCycle: TIntArray): Boolean;
begin
  Result := ContainsNegCycleI(IndexOf(aRoot), aCycle);
end;

function TGWeightedGraph.ContainsNegCycleI(aRootIdx: SizeInt; out aCycle: TIntArray): Boolean;
begin
  CheckIndexRange(aRootIdx);
  aCycle := TWeightHelper.NegCycleDetect(Self, aRootIdx);
  Result := aCycle <> nil;
end;

function TGWeightedGraph.SeparateGraph(constref aVertex: TVertex): TGWeightedGraph;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TGWeightedGraph.SeparateGraphI(aIndex: SizeInt): TGWeightedGraph;
begin
  Result := TGWeightedGraph.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self);
end;

function TGWeightedGraph.SubgraphFromVertexList(const aList: TIntArray): TGWeightedGraph;
begin
  Result := TGWeightedGraph.Create;
  Result.AssignVertexList(Self, aList);
end;

function TGWeightedGraph.SubgraphFromTree(const aTree: TIntArray): TGWeightedGraph;
begin
  Result := TGWeightedGraph.Create;
  Result.AssignTree(Self, aTree);
end;

function TGWeightedGraph.SubgraphFromEdges(const aEdges: TIntEdgeArray): TGWeightedGraph;
begin
  Result := TGWeightedGraph.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TGWeightedGraph.Clone: TGWeightedGraph;
begin
  Result := TGWeightedGraph.Create;
  Result.AssignGraph(Self);
end;

function TGWeightedGraph.MinPathsMap(constref aSrc: TVertex): TWeightArray;
begin
  Result := MinPathsMapI(IndexOf(aSrc));
end;

function TGWeightedGraph.MinPathsMapI(aSrc: SizeInt): TWeightArray;
begin
  CheckIndexRange(aSrc);
  Result := TWeightHelper.DijkstraSssp(Self, aSrc);
end;

function TGWeightedGraph.MinPathsMap(constref aSrc: TVertex; out aPathTree: TIntArray): TWeightArray;
begin
  Result := MinPathsMapI(IndexOf(aSrc), aPathTree);
end;

function TGWeightedGraph.MinPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray): TWeightArray;
begin
  CheckIndexRange(aSrc);
  Result := TWeightHelper.DijkstraSssp(Self, aSrc, aPathTree);
end;

function TGWeightedGraph.FindMinPathsMap(constref aSrc: TVertex; out aWeights: TWeightArray): Boolean;
begin
  Result := FindMinPathsMapI(IndexOf(aSrc), aWeights);
end;

function TGWeightedGraph.FindMinPathsMapI(aSrc: SizeInt; out aWeights: TWeightArray): Boolean;
begin
  CheckIndexRange(aSrc);
  Result := TWeightHelper.BfmtSssp(Self, aSrc, aWeights);
end;

function TGWeightedGraph.FindMinPathsMap(constref aSrc: TVertex; out aPathTree: TIntArray;
  out aWeights: TWeightArray): Boolean;
begin
  Result := FindMinPathsMapI(IndexOf(aSrc), aPathTree, aWeights);
end;

function TGWeightedGraph.FindMinPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray;
  out aWeights: TWeightArray): Boolean;
begin
  CheckIndexRange(aSrc);
  Result := TWeightHelper.BfmtSssp(Self, aSrc, aPathTree, aWeights);
end;

function TGWeightedGraph.MinPathWeight(constref aSrc, aDst: TVertex): TWeight;
begin
  Result := MinPathWeightI(IndexOf(aSrc), IndexOf(aDst));
end;

function TGWeightedGraph.MinPathWeightI(aSrc, aDst: SizeInt): TWeight;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  Result := TWeightHelper.DijkstraPath(Self, aSrc, aDst);
end;

function TGWeightedGraph.MinPath(constref aSrc, aDst: TVertex; out aWeight: TWeight): TIntArray;
begin
  Result := MinPathI(IndexOf(aSrc), IndexOf(aDst), aWeight);
end;

function TGWeightedGraph.MinPathI(aSrc, aDst: SizeInt; out aWeight: TWeight): TIntArray;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  Result := TWeightHelper.DijkstraPath(Self, aSrc, aDst, aWeight);
end;

function TGWeightedGraph.FindMinPath(constref aSrc, aDst: TVertex; out aPath: TIntArray;
  out aWeight: TWeight): Boolean;
begin
  Result := FindMinPathI(IndexOf(aSrc), IndexOf(aDst), aPath, aWeight);
end;

function TGWeightedGraph.FindMinPathI(aSrc, aDst: SizeInt; out aPath: TIntArray; out aWeight: TWeight): Boolean;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  Result := TWeightHelper.BfmtPath(Self, aSrc, aDst, aPath, aWeight);
end;

function TGWeightedGraph.MinPathAStar(constref aSrc, aDst: TVertex; out aWeight: TWeight;
  aEst: TEstimate): TIntArray;
begin
  Result := MinPathAStarI(IndexOf(aSrc), IndexOf(aSrc), aWeight, aEst);
end;

function TGWeightedGraph.MinPathAStarI(aSrc, aDst: SizeInt; out aWeight: TWeight; aEst: TEstimate): TIntArray;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aEst <> nil then
    Result := TWeightHelper.AStar(Self, aSrc, aDst, aWeight, aEst)
  else
    Result := TWeightHelper.DijkstraPath(Self, aSrc, aDst, aWeight);
end;

function TGWeightedGraph.CreateWeightsMatrix: TWeightMatrix;
begin
  Result := TWeightHelper.CreateWeightsMatrix(Self);
end;

function TGWeightedGraph.FindAllPairMinPaths(out aPaths: TApspMatrix): Boolean;
begin
  if IsEmpty then
    exit(False);
  if Density <= DENSE_CUTOFF then
    //if Density <= JOHNSON_CUTOFF then
      Result := TWeightHelper.BfmtApsp(Self, False, aPaths)
    //else
    //  Result := TWeightHelper.JohnsonApsp(Self, aPaths)
  else
    Result := TWeightHelper.FloydApsp(Self, aPaths);
end;

function TGWeightedGraph.ExtractMinPath(constref aSrc, aDst: TVertex; constref aPaths: TApspMatrix): TIntArray;
begin
  Result := ExtractMinPathI(IndexOf(aSrc), IndexOf(aDst), aPaths);
end;

function TGWeightedGraph.ExtractMinPathI(aSrc, aDst: SizeInt; constref aPaths: TApspMatrix): TIntArray;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  Result := TWeightHelper.ExtractMinPath(aSrc, aDst, aPaths);
end;

function TGWeightedGraph.FindEccentricity(constref aVertex: TVertex; out aValue: TWeight): Boolean;
begin
  Result := FindEccentricityI(IndexOf(aVertex), aValue);
end;

function TGWeightedGraph.FindEccentricityI(aIndex: SizeInt; out aValue: TWeight): Boolean;
var
  Weights: TWeightArray;
  I: SizeInt;
  w: TWeight;
begin
  if IsEmpty then
    exit(False);
  Result := FindMinPathsMapI(aIndex, Weights);
  if not Result then
    exit;
  aValue := 0;
  for I := 0 to System.High(Weights) do
    begin
      w := Weights[I];
      if (w < TWeight.INF_VALUE) and (w > aValue) then
        aValue := w;
    end;
end;

function TGWeightedGraph.FindWeightedMerics(out aRadius, aDiameter: TWeight): Boolean;
var
  Bfmt: TWeightHelper.TBfmt;
  Weights: TWeightArray;
  I, J: SizeInt;
  Ecc, w: TWeight;
begin
  if not Connected then
    exit(False);
  Result := TWeightHelper.BfmtReweight(Self, Weights) < 0;
  if not Result then
    exit;
  Weights := nil;
  Bfmt := TWeightHelper.TBfmt.Create(Self, False);
  aRadius := TWeight.INF_VALUE;
  aDiameter := 0;
  for I := 0 to Pred(VertexCount) do
    begin
      Bfmt.Sssp(I);
      Ecc := 0;
      with Bfmt do
        for J := 0 to Pred(VertexCount) do
          if I <> J then
            begin
              w := Nodes[J].Weight;
              if (w < TWeight.INF_VALUE) and (w > Ecc) then
                Ecc := w;
            end;
      if Ecc < aRadius then
        aRadius := Ecc;
      if Ecc > aDiameter then
        aDiameter := Ecc;
    end;
end;

function TGWeightedGraph.FindWeightedCenter(out aCenter: TIntArray): Boolean;
var
  Bfmt: TWeightHelper.TBfmt;
  Eccs: TWeightArray;
  I, J: SizeInt;
  Radius, Ecc, w: TWeight;
begin
  if not Connected then
    exit(False);
  Result := TWeightHelper.BfmtReweight(Self, Eccs) < 0;
  if not Result then
    exit;
  Bfmt := TWeightHelper.TBfmt.Create(Self, False);
  Radius := TWeight.INF_VALUE;
  for I := 0 to Pred(VertexCount) do
    begin
      Bfmt.Sssp(I);
      Ecc := 0;
      with Bfmt do
        for J := 0 to Pred(VertexCount) do
          if I <> J then
            begin
              w := Nodes[J].Weight;
              if (w < TWeight.INF_VALUE) and (w > Ecc) then
                Ecc := w;
            end;
      Eccs[I] := Ecc;
      if Ecc < Radius then
        Radius := Ecc;
    end;
  aCenter.Length := VertexCount;
  J := 0;
  for I := 0 to Pred(VertexCount) do
    if Eccs[I] <= Radius then
      begin
        aCenter[J] := I;
        Inc(J);
      end;
  aCenter.Length := J;
end;

function TGWeightedGraph.MinSpanningTreeKrus(out aTotalWeight: TWeight): TIntArray;
var
  e: TWeightEdge;
  LocEdges: TEdgeArray;
  Dsu: TDisjointSetUnion;
begin
  LocEdges := CreateEdgeArray;
  TEdgeHelper.Sort(LocEdges);
  Result := CreateIntArray;
  Dsu.Size := VertexCount;
  aTotalWeight := 0;
  for e in LocEdges do
    if Dsu.Join(e.Source, e.Destination)  then
      begin
        Result[e.Destination] := e.Source;
        aTotalWeight += e.Weight;
      end;
end;

function TGWeightedGraph.MinSpanningTreePrim(out aTotalWeight: TWeight): TIntArray;
var
  Queue: TPairingHeap;
  Reached,
  InQueue: TBitVector;
  I, Curr: SizeInt;
  Item: TWeightItem;
  p: PAdjItem;
begin
  Result := CreateIntArray;
  Queue := TPairingHeap.Create(VertexCount);
  Reached.Size := VertexCount;
  InQueue.Size := VertexCount;
  aTotalWeight := 0;
  for I := 0 to Pred(VertexCount) do
    if not Reached[I] then
      begin
        Item := TWeightItem.Create(I, 0);
        repeat
          Curr := Item.Index;
          aTotalWeight += Item.Weight;
          Reached[Curr] := True;
          for p in AdjLists[Curr]^ do
            if not Reached[p^.Key] then
              if not InQueue[p^.Key] then
                begin
                  Queue.Enqueue(p^.Key, TWeightItem.Create(p^.Key, p^.Data.Weight));
                  Result[p^.Key] := Curr;
                  InQueue[p^.Key] := True;
                end
              else
                if p^.Data.Weight < Queue.HeadPtr(p^.Key)^.Weight then
                  begin
                    Queue.Update(p^.Key, TWeightItem.Create(p^.Key, p^.Data.Weight));
                    Result[p^.Key] := Curr;
                  end;
        until not Queue.TryDequeue(Item);
      end;
end;

function TGWeightedGraph.IsMaximalMatching(const aMatch: TEdgeArray): Boolean;
begin
  Result := TWeightHelper.IsMaxMatching(Self, aMatch);
end;

function TGWeightedGraph.IsPerfectWeightMatching(const aMatch: TEdgeArray): Boolean;
begin
  Result := TWeightHelper.IsPerfectMatching(Self, aMatch);
end;

{ TPointsChart }

procedure TPointsChart.OnAddEdge(constref aSrc, aDst: TPoint; aData: PEdgeData);
begin
  aData^.Weight := aSrc.Distance(aDst);
end;

procedure TPointsChart.WritePoint(aStream: TStream; constref aValue: TPoint);
var
  p: TPoint;
begin
  p.X := NtoLE(aValue.X);
  p.Y := NtoLE(aValue.Y);
  aStream.WriteBuffer(p, SizeOf(p));
end;

procedure TPointsChart.ReadPoint(aStream: TStream; out aValue: TPoint);
begin
  aStream.ReadBuffer(aValue{%H-}, SizeOf(aValue));
  aValue.X := LEtoN(aValue.X);
  aValue.Y := LEtoN(aValue.Y);
end;

procedure TPointsChart.WriteData(aStream: TStream; constref aValue: TRealWeight);
var
  Buf: Double;
begin
  Buf := aValue.Weight;
  aStream.WriteBuffer(Buf, SizeOf(Buf));
end;

procedure TPointsChart.ReadData(aStream: TStream; out aValue: TRealWeight);
var
  Buf: Double;
begin
  aStream.ReadBuffer(Buf{%H-}, SizeOf(Buf));
  aValue.Weight := Buf;
end;

class function TPointsChart.Distance(constref aSrc, aDst: TPoint): ValReal;
begin
  Result := aSrc.Distance(aDst);
end;

constructor TPointsChart.Create;
begin
  inherited;
  OnStreamReadVertex := @ReadPoint;
  OnStreamWriteVertex := @WritePoint;
  OnStreamReadData := @ReadData;
  OnStreamWriteData := @WriteData;
end;

function TPointsChart.AddEdge(constref aSrc, aDst: TPoint): Boolean;
begin
  Result := inherited AddEdge(aSrc, aDst, TRealWeight.Create(aSrc.Distance(aDst)));
end;

function TPointsChart.AddEdgeI(aSrc, aDst: SizeInt): Boolean;
begin
  Result := inherited AddEdgeI(aSrc, aDst, TRealWeight.Create(Items[aSrc].Distance(Items[aDst])));
end;

function TPointsChart.EnsureConnected(aOnAddEdge: TOnAddEdge): SizeInt;
begin
  if aOnAddEdge <> nil then
    Result := inherited EnsureConnected(aOnAddEdge)
  else
    Result := inherited EnsureConnected(@OnAddEdge);
end;

function TPointsChart.RemoveCutPoints(constref aRoot: TPoint; aOnAddEdge: TOnAddEdge): SizeInt;
begin
  if aOnAddEdge <> nil then
    Result := inherited RemoveCutVertices(aRoot, aOnAddEdge)
  else
    Result := inherited RemoveCutVertices(aRoot, @OnAddEdge);
end;

function TPointsChart.RemoveCutPointsI(aRoot: SizeInt; aOnAddEdge: TOnAddEdge): SizeInt;
begin
  if aOnAddEdge <> nil then
    Result := inherited RemoveCutVerticesI(aRoot, aOnAddEdge)
  else
    Result := inherited RemoveCutVerticesI(aRoot, @OnAddEdge);
end;

function TPointsChart.EnsureBiconnected(aOnAddEdge: TOnAddEdge): SizeInt;
begin
  if aOnAddEdge <> nil then
    Result := inherited EnsureBiconnected(aOnAddEdge)
  else
    Result := inherited EnsureBiconnected(@OnAddEdge);
end;

function TPointsChart.SeparateGraph(aVertex: TPoint): TPointsChart;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TPointsChart.SeparateGraphI(aIndex: SizeInt): TPointsChart;
begin
  Result := TPointsChart.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self);
end;

function TPointsChart.SubgraphFromVertexList(const aList: TIntArray): TPointsChart;
begin
  Result := TPointsChart.Create;
  Result.AssignVertexList(Self, aList);
end;

function TPointsChart.SubgraphFromTree(const aTree: TIntArray): TPointsChart;
begin
  Result := TPointsChart.Create;
  Result.AssignTree(Self, aTree);
end;

function TPointsChart.SubgraphFromEdges(const aEdges: TIntEdgeArray): TPointsChart;
begin
  Result := TPointsChart.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TPointsChart.Clone: TPointsChart;
begin
  Result := TPointsChart.Create;
  Result.AssignGraph(Self);
end;

function TPointsChart.MinPathAStar(constref aSrc, aDst: TPoint; out aWeight: ValReal; aHeur: TEstimate): TIntArray;
begin
  Result := MinPathAStarI(IndexOf(aSrc), IndexOf(aDst), aWeight, aHeur);
end;

function TPointsChart.MinPathAStarI(aSrc, aDst: SizeInt; out aWeight: ValReal; aHeur: TEstimate): TIntArray;
begin
  if aHeur = nil then
    Result := inherited MinPathAStarI(aSrc, aDst, aWeight, @Distance)
  else
    Result := inherited MinPathAStarI(aSrc, aDst, aWeight, aHeur);
end;

{$I IntGraphHelp.inc}

{ TGIntWeightGraph }

function TGIntWeightGraph.GetTrivialMinCut(out aCutSet: TIntSet; out aCutWeight: TWeight): Boolean;
var
  d: TEdgeData;
begin
  {%H-}aCutSet.MakeEmpty;
  if not Connected or (VertexCount < 2) then
    begin
      aCutWeight := 0;
      exit(True);
    end;
  if VertexCount = 2 then
    begin
      d := Default(TEdgeData);
      GetEdgeDataI(0, 1, d);
      aCutWeight := d.Weight;
      aCutSet.Add(0);
      exit(True);
    end;
  Result := False;
end;

function TGIntWeightGraph.GetTrivialMinCut(out aCut: TWeight): Boolean;
var
  d: TEdgeData;
begin
  if not Connected or (VertexCount < 2) then
    begin
      aCut := 0;
      exit(True);
    end;
  if VertexCount = 2 then
    begin
      d := Default(TEdgeData);
      GetEdgeDataI(0, 1, d);
      aCut := d.Weight;
      exit(True);
    end;
  Result := False;
end;

function TGIntWeightGraph.StoerWagner(out aCut: TIntSet): TWeight;
var
  Queue: TPairHeapMax;
  g: array of TSWAdjList;
  Cuts: array of TIntSet;
  vRemains, vInQueue: TBoolVector;
  Phase, Prev, Last, I: SizeInt;
  p: PAdjItem;
  pItem: ^TWeightItem;
  NextItem: TWeightItem;
begin
  //initialize
  System.SetLength(g, VertexCount);
  for I := 0 to Pred(VertexCount) do
    begin
      g[I].EnsureCapacity(DegreeI(I));
      for p in AdjLists[I]^ do
        g[I].Add(TWeightItem.Create(p^.Destination, p^.Data.Weight));
    end;
  System.SetLength(Cuts, VertexCount);
  for I := 0 to Pred(VertexCount) do
    Cuts[I].Add(I);
  Queue := TPairHeapMax.Create(VertexCount);
  vRemains.InitRange(VertexCount);
  vInQueue.Size := VertexCount;
  Result := MAX_WEIGHT;
  //n-1 phases
  for Phase := 1 to Pred(VertexCount) do
    begin
      vInQueue.Join(vRemains);
      for I in vRemains do
        Queue.Enqueue(I, TWeightItem.Create(I, 0));
      while Queue.Count > 1 do
        begin
          Prev := Queue.Dequeue.Index;
          vInQueue[Prev] := False;
          for pItem in g[Prev] do
            if vInQueue[pItem^.Index] then
              begin
                NextItem := Queue.Peek(pItem^.Index);
                NextItem.Weight += pItem^.Weight;
                Queue.Update(pItem^.Index, NextItem);
              end;
        end;
      NextItem := Queue.Dequeue;
      Last := NextItem.Index;
      vInQueue[NextItem.Index] := False;
      if Result > NextItem.Weight then
        begin
          Result := NextItem.Weight;
          aCut.Assign(Cuts[Last]);
        end;
      while Cuts[Last].TryPop(I) do
        Cuts[Prev].Push(I);
      Finalize(Cuts[Last]);
      vRemains[Last] := False;
      //merge last two vertices, remain Prev
      g[Prev].Remove(Last);
      g[Last].Remove(Prev);
      g[Prev].AddAll(g[Last]);
      for pItem in g[Last] do
        begin
          I := pItem^.Index;
          NextItem := pItem^;
          g[I].Remove(Last);
          NextItem.Index := Prev;
          g[I].Add(NextItem);
        end;
      Finalize(g[Last]);
    end;
end;

function TGIntWeightGraph.SeparateGraph(constref aVertex: TVertex): TGIntWeightGraph;
begin
  Result := inherited SeparateGraph(aVertex) as TGIntWeightGraph;
end;

function TGIntWeightGraph.SeparateGraphI(aIndex: SizeInt): TGIntWeightGraph;
begin
  Result := inherited SeparateGraphI(aIndex) as TGIntWeightGraph;
end;

function TGIntWeightGraph.SubgraphFromVertexList(const aList: TIntArray): TGIntWeightGraph;
begin
  Result := inherited SubgraphFromVertexList(aList) as TGIntWeightGraph;
end;

function TGIntWeightGraph.SubgraphFromTree(const aTree: TIntArray): TGIntWeightGraph;
begin
  Result := inherited SubgraphFromTree(aTree) as TGIntWeightGraph;
end;

function TGIntWeightGraph.SubgraphFromEdges(const aEdges: TIntEdgeArray): TGIntWeightGraph;
begin
  Result := inherited SubgraphFromEdges(aEdges) as TGIntWeightGraph;
end;

function TGIntWeightGraph.Clone: TGIntWeightGraph;
begin
  Result := TGIntWeightGraph.Create;
  Result.AssignGraph(Self);
end;

function TGIntWeightGraph.FindBipartiteMinWeightMatching(out aMatch: TEdgeArray): Boolean;
var
  w, g: TIntArray;
begin
  if not IsBipartite(w, g) then
    exit(False);
  aMatch := TWeightHelper.MinWeightMatchingB(Self, w, g);
  Result := True;
end;

function TGIntWeightGraph.FindBipartiteMaxWeightMatching(out aMatch: TEdgeArray): Boolean;
var
  w, g: TIntArray;
begin
  if not IsBipartite(w, g) then
    exit(False);
  aMatch := TWeightHelper.MaxWeightMatchingB(Self, w, g);
  Result := True;
end;

function TGIntWeightGraph.MinWeightCutSW(out aCut: TCut): TWeight;
var
  Cut: TIntSet;
  B: TBoolVector;
  I: SizeInt;
begin
  if not GetTrivialMinCut(Cut, Result) then
    Result := StoerWagner(Cut);
  B.InitRange(VertexCount);
  for I in Cut do
    B[I] := False;
  aCut.A := Cut.ToArray;
  aCut.B := B.ToArray;
end;

function TGIntWeightGraph.MinWeightCutNI: TWeight;
var
  Helper: TNIMinCutHelper;
begin
  if not GetTrivialMinCut(Result) then
    Result := Helper.GetMinCut(Self);
end;

function TGIntWeightGraph.MinWeightCutNI(out aCut: TCut): TWeight;
var
  Helper: TNIMinCutHelper;
  Cut: TIntSet;
  Total: TBoolVector;
  I: SizeInt;
begin
  if not GetTrivialMinCut(Cut, Result) then
    Result := Helper.GetMinCut(Self, Cut);
  Total.InitRange(VertexCount);
  for I in Cut do
    Total[I] := False;
  aCut.A := Cut.ToArray;
  aCut.B := Total.ToArray;
end;

function TGIntWeightGraph.CrossMinWeightCut: TEdgeArray;
var
  Helper: TNIMinCutHelper;
  Cut: TIntSet;
  Left, Right: TBoolVector;
  I, J: SizeInt;
  p: PAdjItem;
  d: TEdgeData;
begin
  if not Connected or (VertexCount < 2) then
    exit([]);
  d := Default(TEdgeData);
  if VertexCount = 2 then
    begin
      GetEdgeDataI(0, 1, d);
      exit([TWeightEdge.Create(0, 1, d.Weight)]);
    end;
  Helper.GetMinCut(Self, Cut);
  if Cut.Count <= VertexCount shr 1 then
    begin
      Left.Size := VertexCount;
      Right.InitRange(VertexCount);
      for I in Cut do
        begin
          Left[I] := True;
          Right[I] := False;
        end;
    end
  else
    begin
      Right.Size := VertexCount;
      Left.InitRange(VertexCount);
      for I in Cut do
        begin
          Right[I] := True;
          Left[I] := False;
        end;
    end;
  System.SetLength(Result, Cut.Count);
  J := 0;
  for I in Left do
    for p in AdjLists[I]^ do
      if Right[p^.Destination] then
        begin
          GetEdgeDataI(I, p^.Destination, d);
          if I < p^.Destination then
            Result[J] := TWeightEdge.Create(I, p^.Destination, d.Weight)
          else
            Result[J] := TWeightEdge.Create(p^.Destination, I, d.Weight);
          Inc(J);
        end;
end;

end.

