unit Analytics.UnitMetrics;

interface

uses
  System.Generics.Collections,
  DelphiAST.Classes,
  DelphiAST.Consts,
  Analytics.MethodMetrics,
  Utils.IntegerArray;

type
  TUnitMetrics = class
  private
    fName: string;
    fMethods: TObjectList<TMethodMetrics>;
    procedure AddMethod(aMethodNode: TCompoundSyntaxNode);
  public
    constructor Create(const aUnitName: string);
    destructor Destroy; override;
    procedure CalculateMetrics(aRootNode: TSyntaxNode);
    property Name: string read fName;
    function MethodsCount(): Integer;
    function GetMethod(aIdx: Integer): TMethodMetrics;
  end;

implementation

constructor TUnitMetrics.Create(const aUnitName: string);
begin
  self.fName := aUnitName;
  fMethods := TObjectList<TMethodMetrics>.Create();
end;

destructor TUnitMetrics.Destroy;
begin
  fMethods.Free;
  inherited;
end;

function TUnitMetrics.GetMethod(aIdx: Integer): TMethodMetrics;
begin
  Result := fMethods[aIdx];
end;

function TUnitMetrics.MethodsCount: Integer;
begin
  Result := fMethods.Count;
end;

// --------------------------------------------------

var
  fLineIndetation: TDictionary<Integer, Integer>;

procedure MinIndetationNodeWalker(const aNode: TSyntaxNode);
var
  child: TSyntaxNode;
  indentation: Integer;
begin
  if aNode <> nil then
  begin
    if fLineIndetation.TryGetValue(aNode.Line, indentation) then
    begin
      if aNode.Col < indentation then
        fLineIndetation[aNode.Line] := aNode.Col - 1;
    end
    else
      fLineIndetation.Add(aNode.Line, aNode.Col - 1);
    for child in aNode.ChildNodes do
      MinIndetationNodeWalker(child);
  end;
end;

function CalculateMethodIndentation(const aMethodNode: TCompoundSyntaxNode)
  : TIntegerArray;
var
  statements: TSyntaxNode;
begin
  fLineIndetation := TDictionary<Integer, Integer>.Create();
  try
    statements := aMethodNode.FindNode(ntStatements);
    MinIndetationNodeWalker(statements);
    Result := fLineIndetation.Values.ToArray.GetDistinctArray();
  finally
    fLineIndetation.Free;
  end;
end;

function CalculateMethodLength(const aMethodNode: TCompoundSyntaxNode): Integer;
var
  statements: TCompoundSyntaxNode;
begin
  statements := aMethodNode.FindNode(ntStatements) as TCompoundSyntaxNode;
  if statements <> nil then
    Result := statements.EndLine - aMethodNode.Line + 1
  else
    Result := 1;
end;

procedure TUnitMetrics.AddMethod(aMethodNode: TCompoundSyntaxNode);
var
  indentations: TIntegerArray;
  level: Integer;
  step: Integer;
begin
  indentations := CalculateMethodIndentation(aMethodNode);
  level := 0;
  if Length(indentations) >= 2 then
  begin
    step := indentations[1] - indentations[0];
    level := (indentations[High(indentations)] - indentations[1]) div step;
  end;
  fMethods.Add(TMethodMetrics.Create(
    { } aMethodNode.GetAttribute(anKind),
    { } aMethodNode.GetAttribute(anName),
    { } CalculateMethodLength(aMethodNode),
    { } level));
end;

procedure TUnitMetrics.CalculateMetrics(aRootNode: TSyntaxNode);
var
  implementationNode: TSyntaxNode;
  child: TSyntaxNode;
begin
  // ---- interfaceNode := aRootNode.FindNode(ntInterface);
  implementationNode := aRootNode.FindNode(ntImplementation);
  for child in implementationNode.ChildNodes do
    if child.Typ = ntMethod then
      AddMethod(child as TCompoundSyntaxNode);
end;

end.
