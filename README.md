# GmshLink

[Mathematica](http://www.wolfram.com/mathematica/) package to create `ElementMesh` objects via [Gmsh](http://gmsh.info/) meshing software.

It creates tetrahedral mesh with much better quality than built-in meshing algorithm.
Currently it works only for 3D symbolic regions obtained by boolean operations on
basic geometric primitives (`Cuboid`, `Ball`, `Cylinder` and `Cone`).

## Usage

### Prerequisites

* The latest release (4.0+) of open source meshing software [Gmsh](http://gmsh.info/).
* [ImportMesh](http://github.com/c3m-labs/ImportMesh) (0.3.2) package to import .msh files to Mathematica.

Gmsh doesn't require installation, just unzip it to any local directory. 
Then copy the `GmshLink.wl` file to your local path `FileNameJoin[{$UserBaseDirectory, "Applications"}]` and
you can already try the following example in Mathematica notebook.

```mathematica
 (* Load the package. *)
Get["GmshLink`"]

(* Set your path to Gmsh executable. *)
$GmshDirectory ="local/path/to/Gmsh.exe";

(* Define symbolic region based on boolean operations with geometric primitives. *)
reg = RegionDifference[
  RegionUnion@{
    Ball[{0, 0, 0}, 1],
    Ball[{1, 0, 0}, 4/5],
    Ball[{9/5, 0, 0}, 3/5],
    Ball[{12/5, 0, 0}, 2/5]
    },
  Cuboid[{-2, -2, 0}, {5, 2, 2}]
]

(* Create ElementMesh object from symbolic region. *)
mesh = ToElementMesh[reg,"ElementMeshGenerator" -> GmshGenerator]

mesh["Wireframe"[
    "MeshElement" -> "MeshElements",
    "MeshElementStyle" -> FaceForm@LightBlue
]]
```

![mesh](Images/ExampleBalls.png)
