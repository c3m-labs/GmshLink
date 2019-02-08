(* ::Package:: *)

(* ::Section:: *)
(*Begin package*)


(* ::Subsection:: *)
(*Header comments*)


(* :Title: GmshLink *)
(* :Context: GmshLink` *)
(* :Author: Pintar M, C3M, Slovenia *)
(* :Summary: Package for creating ElementMesh from 3D BooleanRegion via GMSH software. *)
(* :Copyright: C3M d.o.o., 2019 *)


(* ::Subsection:: *)
(*Define Context*)


(* "ImportMesh" package is needed to import meshes from .msh file. 
Download and install "ImportMesh" package version 0.3.2 from: 
https://github.com/c3m-labs/ImportMesh/releases *)
BeginPackage["GmshLink`",{"NDSolve`FEM`","ImportMesh`"}];


(* ::Subsection:: *)
(*Public symbols*)


$GmshDirectory;
GmshGenerator;


(* ::Section:: *)
(*Code*)


(* Begin private context *)
Begin["`Private`"];

gmshExecutableName[] := 
	If[ $OperatingSystem === "Windows",
		"gmsh.exe"
	,
		"gmsh"
	];

(* ::Subsection:: *)
(*Geometric primitives*)


getPrimitive[Cuboid[{x1_,y1_,z1_}],n_]:=StringJoin[
	"Box(",ToString[n],") = ",ToString[CForm/@{x1,y1,z1,1,1,1}],";"
]

getPrimitive[Cuboid[{x1_,y1_,z1_},{x2_,y2_,z2_}],n_]:=StringJoin[
	"Box(",ToString[n],") = ",ToString[CForm/@{x1,y1,z1,x2-x1,y2-y1,z2-z1}],";"
]

getPrimitive[Ball[{x_,y_,z_}],n_]:=StringJoin[
	"Sphere(",ToString[n],") = ",ToString[CForm/@{x,y,z,1}],";"
]

getPrimitive[Ball[{x_,y_,z_},r_],n_]:=StringJoin[
	"Sphere(",ToString[n],") = ",ToString[CForm/@{x,y,z,r}],";"
]

getPrimitive[Cylinder[{{x1_,y1_,z1_},{x2_,y2_,z2_}}],n_]:=StringJoin[
	"Cylinder(",ToString[n],") = ",ToString[CForm/@{x1,y1,z1,x2-x1,y2-y1,z2-z1,1}],";"
]

getPrimitive[Cylinder[{{x1_,y1_,z1_},{x2_,y2_,z2_}},r_],n_]:=StringJoin[
	"Cylinder(",ToString[n],") = ",ToString[CForm/@{x1,y1,z1,x2-x1,y2-y1,z2-z1,r}],";"
]

getPrimitive[Cone[{{x1_,y1_,z1_},{x2_,y2_,z2_}}],n_]:=StringJoin[
	"Cone(",ToString[n],") = ",ToString[CForm/@{x1,y1,z1,x2-x1,y2-y1,z2-z1,1,0}],";"
]

getPrimitive[Cone[{{x1_,y1_,z1_},{x2_,y2_,z2_}},r_],n_]:=StringJoin[
	"Cone(",ToString[n],") = ",ToString[CForm/@{x1,y1,z1,x2-x1,y2-y1,z2-z1,r,0}],";"
]


(* ::Subsection:: *)
(*Geometric operations*)


Clear[union,diff,inter]


(* Simplify the tree of boolean operations to be easily processed latter.
Especially difference and intersection operations have to be separated. *)
makeBooleanTree[reg_]:=Module[
	{tree,newTree,rules},
	
	If[
		Head[reg]=!=BooleanRegion,
		Return[$Failed,Module]
	];
	
	tree=First@ReplaceAll[First[reg],Slot[x_]:>x];
	
	rules={
		Or[a_,b__]:>union[a,b],
		And[a_,b__]:>Fold[
			If[Head[#2]===Not,diff[#1,First@#2],inter[#1,#2]]&,
			a,
			{b}
		]
	};
	newTree=tree//.rules;
	newTree
]


gmshCommand[command_String,n_,a_,b_]:=With[{
	ts=(StringJoin@@Riffle[ToString/@Flatten[{#}],","])&
	},
	StringJoin[
		command,"(",ts[n],") = ",
		"{Volume{",ts[a],"}; Delete; }",
		"{Volume{",ts[b],"}; Delete; };"
	]
]


(* Read the whole tree of boolean operations (in backward direction) and transform
it to a list of Gmsh commands. *)
getOperations[reg_]:=Module[
	{tree,newTree,depth,bag,writeLines,n},
	
	tree=makeBooleanTree[reg];
	depth=Depth[tree];
	
	writeLines={
		union[a_,b__]:>(n++;AppendTo[bag,gmshCommand["BooleanUnion",n,a,{b}]];n),
		diff[a_,b__]:>(n++;AppendTo[bag,gmshCommand["BooleanDifference",n,a,{b}]];n),
		inter[a_,b__]:>(n++;AppendTo[bag,gmshCommand["BooleanIntersection",n,a,{b}]];n)
	};
	
	n=Max@Cases[tree,_Integer,Infinity];
	bag={};
	
	newTree=tree;
	Do[
		newTree=Replace[newTree,writeLines,{i}],
		{i,depth,0,-1}
	];
	bag
]


(* Transform whole BooleanRegion expression to list of Gmsh commands for 
geometric primitive definition and boolean operations definitinos. *)
processBooleanRegion[reg_BooleanRegion]:=Module[
	{primitives,operations},

	primitives=MapIndexed[
		getPrimitive[#1,First[#2]]&,
		Last[reg]
	];
	operations=getOperations[reg];
	Join[
		primitives,
		{"\n"},
		operations
	]
]


(* ::Subsection:: *)
(*Main function*)


exportInputFile[content_,name_String]:=Module[
	{dir,file},
	(* File is saved to $TemporaryDirectory if notebook is not saved. *)
	dir=If[
		$Notebooks,
		(NotebookDirectory[]/.$Failed->$TemporaryDirectory)//Quiet,
		Directory[]
	];
	file=FileNameJoin[{dir,name<>".geo"}];
	Export[file,content,"Lines"]
]


(* Wraps string escape character around strings. *)
If[ $OperatingSystem === "Windows",
	quotes[str_String]:="\""<>str<>"\"";
	quotes[other_]:=other
,
	quotes = Identity
];


(* Needs Gmsh version 4.0 or higher. *)

GmshGenerator::usage="GmshGenerator[nr] creates ElementMesh via Gmsh software.";
GmshGenerator::badregion="Only BooleanRegion regions are supported.";
GmshGenerator::algo="Gmsh algorithm `1` is not supported. Available options are `2`.";
GmshGenerator::primitive="Only Cuboid, Ball, Cylinder and Cone basic geometric regions are supported.";
GmshGenerator::exe="Gmsh executable not found in given directory.";
GmshGenerator::fail="Meshing procedure failed in Gmsh. Try to import .geo file interactively (with GUI).";

GmshGenerator//Options={
	"DeleteFiles"->True, (* Whether to delete indermediate files. *)
	"GmshAlgorithm"->Automatic,
	"GmshDirectory"->$GmshDirectory,
	"MeshOrder"->1,
	MaxCellMeasure->Automatic
};

GmshGenerator//SyntaxInformation={"ArgumentsPattern"->{_,OptionsPattern[]}};

GmshGenerator[nr_NumericalRegion,opts:OptionsPattern[]]:=Module[
	{exePath,reg,algorithm,minBound,size,order,header,content,geoFile,mshFile,cmd,mesh},

	exePath=FileNameJoin[{OptionValue["GmshDirectory"], gmshExecutableName[]}];

	If[
		Not@TrueQ@Quiet@FileExistsQ[exePath],
		Message[GmshGenerator::exe];Return[$Failed,Module]
	];
	
	reg=nr["SymbolicRegion"];
	If[
		Not@MatchQ[reg,_BooleanRegion],
		Message[GmshGenerator::badregion];Return[$Failed,Module]
	];
	
	If[
		Not@ContainsOnly[Head/@Last[reg],{Cuboid,Ball,Cylinder,Cone}],
		Message[GmshGenerator::primitive];Return[$Failed,Module]
	];
	
	minBound=Min@Flatten[Differences/@nr["Bounds"]];
	size=N@Replace[
		OptionValue[MaxCellMeasure],
		Except[_?NumberQ]:>(minBound/10.)
	];
	
	order=OptionValue["MeshOrder"]/.Except[1|2]->1;
	With[
		{available={Automatic,"Delaunay","Frontal","MeshAdapt"}},
		algorithm=OptionValue["GmshAlgorithm"];
		If[
			Not@MemberQ[available,algorithm],
			Message[GmshGenerator::algo,algorithm,available];algorithm=Automatic
		];
		algorithm=algorithm/.Thread[available->{2,5,6,1}]
	];
		
	header={
		"SetFactory(\"OpenCASCADE\");",
		"\n",
		"Mesh.CharacteristicLengthMin = "<>ToString[size/2]<>";",
		"Mesh.CharacteristicLengthMax = "<>ToString[size]<>";",
		"Mesh.Algorithm = "<>ToString[algorithm]<>";",
		"\n"
	};
	content=processBooleanRegion[reg];
	
	geoFile=exportInputFile[Join[header,content],"GmshLink"];
	mshFile=StringReplace[geoFile,".geo"->".msh"];
	
	cmd=quotes@StringJoin@StringRiffle[{
		quotes@exePath,
		quotes@geoFile,
		"-3",
		"-order",order,
		"-format msh2",
		"-optimize_netgen",
		"-o",quotes@mshFile
	}];

	If[
		Run[cmd]=!=0,
		Message[GmshGenerator::fail];Return[$Failed,Module]
	];
	
	mesh=ImportMesh[mshFile];
	If[
		TrueQ@OptionValue["DeleteFiles"],
		DeleteFile[{geoFile,mshFile}]
	];
	mesh
]


(* ::Section:: *)
(*End package*)


End[]; (* "`Private`" *)


EndPackage[];
