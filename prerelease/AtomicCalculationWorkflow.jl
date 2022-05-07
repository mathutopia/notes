### A Pluto.jl notebook ###
# v0.19.2

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 77b67d46-c744-11ec-35f0-977442515424
# ╠═╡ show_logs = false
begin
    import Pkg
    Pkg.activate(mktempdir())
	ENV["PYTHON"] = ""
    Pkg.add(["Conda",
			 "PyCall",
			 "DFTK",
			 "Unitful","UnitfulAtomic",
			 "Plots",
			 "PlutoUI",
			 "HypertextLiteral",
			 "ShortCodes"])
	Pkg.build()
end

# ╔═╡ 3ac79a39-aca4-4f1f-a065-241029866dc5
# ╠═╡ show_logs = false
begin
	using Conda
	Conda.add("pymatgen",channel="conda-forge")
	Conda.pip_interop(true)
	Conda.pip("install --upgrade","ase")
end

# ╔═╡ f40a2100-99a4-4c10-9b9b-2beb0efec6f9
# ╠═╡ show_logs = false
begin
	using PlutoUI
	using PyCall
	using Plots; plotly();
	using DFTK, Unitful, UnitfulAtomic
end

# ╔═╡ f2ad5416-8ed2-4c1c-951e-41b62bd7f7b4
begin
	using HypertextLiteral
	using ShortCodes
end

# ╔═╡ 3bffff9a-f4bd-403d-8581-0b09a1cab911
md"""
# Density Functional theory calculations in a Pluto.jl notebook
**Author: Stefan Bringuier**

As the Julia ecosystem continues to mature its becoming easier and very attractive to use the packages to do routine DFT and atomistic calculations. This notebook attempts to show how one can use [DFTK.jl](), a density functional theory toolkit which gives access to many primitives for scripting a calculation. The package has a good amount of capability for being so young. What makes this even a more attractive is that routines exist to utilize well established structure/calculation preparation libraries such as [ASE]() and [pymatgen](). This is all enabled by [PyCall.jl] and made even easier with [Conda.jl]. Finally, computation notebooks are commonly used to do data analysis and prototyping given that they have a "natural" feeling for how many computational practioniers think, [Pluto.jl]() is a native Julia approach to notebooks. It provides some nice stylistic choices that I think a better than [Jupyter]() in addition to a different approach to code execution and relation.

In this notebook I will just be demonstrating a workflow that maybe useful for exploring DFT calculation ideas or initial setup. I won't go over the individual packages and setup but at the [end of the notebook](#Adding-packages) is how I've done it for this notebook.  Key references for the packages can be are on the side.
"""

# ╔═╡ 3a662cf4-60d4-45d7-a9af-dfca1659dde8
md"""
# Example with pymatgen API & ASE
"""

# ╔═╡ b4a7ab05-4819-43cf-a25f-b043a64a30b1
md"""
Materials Project REST API key: $(@bind API PasswordField())
!!! note
	You need to register with [Materials Project]() to get your API key.
"""

# ╔═╡ d36ca560-186b-44e9-88c2-01dc6fc8e701
md"""
The first thing is to create a function that will grab a structure from the materials project database. Here we will require that it is a materials project id entry (e.g. mp-1620) format. Futhermore, we will add the keyword argument with default value to `true` to return an `ase.Atom` python data object. This makes using the `ASE` input/output easy.
"""

# ╔═╡ ee49f2bc-7467-4387-81db-178700742be7
md"""
I've decided to generate a list of materials project ideas based on a query for Lithium hydrogen compounds. You can select one from the box below and then we retrieve it.
"""

# ╔═╡ 86e64077-858c-4313-8ecd-649244f08942
mpid = "mp-23703"

# ╔═╡ 8bbc2cfd-c349-4990-a516-902358bb3522
md"""
Now using various `ASE` methods and modules we can modify and visualize. Here I'm going to focus on just scaling the cell volume and use this to see how the total energy will change with our DFT calculation.
"""

# ╔═╡ d09d7791-15b6-4d70-8f36-3fd9b649d5f2
md"""
Rotate X : $(@bind rx Slider(-45:5:45,default=15,show_value=true))

Rotate Y : $(@bind ry Slider(-45:5:45,default=0,show_value=true))

Rotate Z : $(@bind rz Slider(-45:5:45,default=45,show_value=true))
"""

# ╔═╡ 0a42c388-7ede-4e52-8dc9-ff9d34f26cb8
md"""
Image of modified structure:  $(DownloadButton(read(mpid*"-mod.png"), mpid*".png"))

POSCAR file of modified structure:  $(DownloadButton(read(mpid*"-mod.vasp"), mpid*".POSCAR"))
"""

# ╔═╡ 01081a84-6caf-4bd1-9263-cd0bc13b9e8b
md"""
# Running DFTK.jl

So now with the structure in had we can setup our DFTK.jl calculation in a few number of lines. The first block of code is to convert the `ASE` (or `pymatgen`) structures into what DFTK likes. Then we need to specify the psuedopotential for a given functional. DFTK.jl at the moment has limited support for psuedopotentials. 

The calculation will take some time ...
"""

# ╔═╡ a689c4bc-157a-4b15-87d6-8eb50578241c
md"""
Here I create some storage arrays. As you'll see below there is a entry box to specify what affine transformation scaling to apply. This is used to generate the equation of state for the compound.
"""

# ╔═╡ 3f387862-434c-44b8-ad9b-dbec1e7e28bd
begin
	volumes,energies = [],[]
	bandplots = []
end;

# ╔═╡ 6c76f776-65b1-45bc-bdb4-be10498c9ea0
md"""
We can generate the equation of state by scaling the unit cell uniformly. Adjust scale cell by: $(@bind scale confirm(NumberField(0.575:0.1:1.6,default=0.575)))
"""

# ╔═╡ 44077c63-3772-4196-bb08-1ce5f25407d0
begin
	xy = sort(collect(zip(volumes,energies)); by=first)
	plot(x->x[1],y->y[2],xy,markershape=:auto,
	 	label="scaling=$(scale)",legend=false,
	 	xlabel="Volume [Å³]",ylabel="Total Energy [eV]",
	 	title="Binding Curve for $(mpid), LDA",titlefontsize=10)
end

# ╔═╡ ef047bdb-8ace-4524-b345-32764dd2f9c1
md"""
Show bandstructure plots $(@bind showbandplot CheckBox()) $(@bind replot Button("Replot"))
"""

# ╔═╡ a9adf571-0c6a-4290-b7d6-8c47d959e677
if showbandplot
	replot
	plot(bandplots...,xlabel=false,ylabel=false,ylims=[-5,9])
end

# ╔═╡ bda1a5a9-a8c8-48f6-bf9e-c481ed96a305
md"""
Generally the band structure shows that at high compression the compound is predicted to be metallic and upon expansion transitions to insulating. This is all based upon the LDA approximation.

For reference here is the ground state prediction using GGA from the materials project page:

$(Resource("https://materialsproject.org/electronic_structure/bandstructure/plot/mp-23703",MIME"image/png"(),()))
"""

# ╔═╡ 4971e8c1-670f-454d-85d3-826912124a52
md"""
# Adding packages
"""

# ╔═╡ 02b9042f-ffe3-4ec4-b7af-4e362d315cb1
md"""
## Adding Julia packages"""

# ╔═╡ 3626cc10-6069-488c-a121-e3e46ef42ded
md"""
Here I'm using the old way of adding packages in a `Pluto.jl` notebook. The reason for this is because I want to ensure the correct setup for python.
"""

# ╔═╡ 1a397e28-53ba-4a58-a40d-fba4535ae0a6
md"""
## Add python packages via Conda.jl
The `DFTK.jl` package is able to take advantage of the [pymatgen]() and [ase]() packages for working with atomic structures. For the [pymatgen]() package you need to obtain an API token by signing up.
"""

# ╔═╡ d4887776-e18f-4f69-9fbc-9661abfbb36d
md"""
## Package use
### Julia
"""

# ╔═╡ df058d03-8578-4b22-b59e-e8b2c2e1ce44
TableOfContents()

# ╔═╡ 16858060-1b0d-4d1f-a134-63e37ddf3a88
md"""
### Python imports
"""

# ╔═╡ 28322e9b-baba-49cc-adbd-15465787dfcb
begin
	ase_build = pyimport("ase.build")
	aseio = pyimport("ase.io")
	mp = pyimport("pymatgen.ext.matproj")
	mp_to_ase = pyimport("pymatgen.io.ase").AseAtomsAdaptor()
end;

# ╔═╡ be5c12a5-5367-4c78-83c5-590f88cb81e4
function get_structure_pymatgen(mpid::String;ase=true) 		
	structure = mp.MPRester(api_key=API).get_structure_by_material_id(mpid)
	ase ? mp_to_ase.get_atoms(structure) : structure
end;

# ╔═╡ bb02711c-844f-4bbb-8954-f34f1488cac6
structure = get_structure_pymatgen(mpid);

# ╔═╡ 197f95f2-5f1a-48d8-b5d0-4d466a7650a0
begin
	modstructure = get_structure_pymatgen(mpid)
	oldcell = structure.get_cell()
	oldscalepos = structure.get_scaled_positions()
	modstructure.set_cell(scale*oldcell)
	modstructure.set_scaled_positions(oldscalepos)
	aseio.write("$(mpid)-mod.vasp",modstructure)
	aseio.write("$(mpid)-mod.png",modstructure*(3,3,3),rotation="$(rz)z,$(rx)x,$(ry)y")
	LocalResource("$(mpid)-mod.png",:style=>"display: block; margin-left: auto; margin-right: auto;")
end

# ╔═╡ c5e39ebb-f3a2-4f76-b015-6b0524df075a
begin
	positions = load_positions(modstructure)
	lattice = load_lattice(modstructure)
	atoms = map(load_atoms(modstructure)) do el
		if el.symbol == :Li
			ElementPsp(:Li,psp=load_psp("hgh/lda/li-q1"))
		elseif el.symbol == :H
			ElementPsp(:H,psp=load_psp("hgh/lda/h-q1"))	
		end
	end
end;

# ╔═╡ 83b24435-e363-4ad2-abda-2eb32df3f4da
# ╠═╡ show_logs = false
begin
	Ecut, kgrid = 600u"eV", [9,9,9]
	model = model_LDA(lattice, atoms, positions,
                  temperature=0.01, smearing=DFTK.Smearing.Gaussian())
	basis = PlaneWaveBasis(model; Ecut, kgrid)
	# Check if volume already exist.
	v = austrip.(auconvert(u"angstrom^3",model.unit_cell_volume))
	if v ∉ volumes
		scfres = self_consistent_field(basis, tol=1e-6, mixing=LdosMixing());
		# Store result
		e = austrip.(auconvert(u"eV",scfres.energies.total))
		append!(energies,e)
		append!(volumes,v)
		push!(bandplots,plot_bandstructure(scfres,unit=u"eV"))
	end
end;

# ╔═╡ dea77925-e281-4a0e-9825-685f47876ed4
md"""
# Notebook formatting & add-ons
"""

# ╔═╡ 30943ccc-60ed-4688-84ee-4aa1e5bde97c
function aside(x;side="left")
	width = Dict("left"=>"-550px","right"=>"-11px")
	sidefrmt = "$(side): $(width[side])"
	@htl("""
		<style>
		@media (min-width: calc(700px + 30px + 300px)) {
			aside.plutoui-aside-wrapper {
				position: absolute;
				$(sidefrmt);
				width: 0px;
				transform: translate(0, -40%);
			}
			aside.plutoui-aside-wrapper > div {
				width: 500px;
				height: 450px;
			}
		}
		</style>
		
		<aside class="plutoui-aside-wrapper">
		<div>
		$(x)
		</div>
		</aside>
		""")
end

# ╔═╡ 10738fff-fc8b-4668-a4b3-5115f63a5dc0
aside(md"""
**Pluto & DFTK Refs.**
- $(DOI("10.5281/zenodo.6498231"))


- $(DOI("10.21105/jcon.00069"))

**Python Package Refs.**
- $(DOI("10.1088/1361-648X/aa680e"))


- $(DOI("10.1016/j.commatsci.2012.10.028"))
""")

# ╔═╡ 9d2256ed-4faf-494e-8746-83eb8a4bdaeb
aside(md"""
!!! note
    The bandstructure plots are not sorted, so if you change the scaling out of order the plots will not correspond accordingly.
""")

# ╔═╡ Cell order:
# ╟─3bffff9a-f4bd-403d-8581-0b09a1cab911
# ╟─10738fff-fc8b-4668-a4b3-5115f63a5dc0
# ╟─3a662cf4-60d4-45d7-a9af-dfca1659dde8
# ╟─b4a7ab05-4819-43cf-a25f-b043a64a30b1
# ╟─d36ca560-186b-44e9-88c2-01dc6fc8e701
# ╠═be5c12a5-5367-4c78-83c5-590f88cb81e4
# ╟─ee49f2bc-7467-4387-81db-178700742be7
# ╠═86e64077-858c-4313-8ecd-649244f08942
# ╠═bb02711c-844f-4bbb-8954-f34f1488cac6
# ╟─8bbc2cfd-c349-4990-a516-902358bb3522
# ╟─d09d7791-15b6-4d70-8f36-3fd9b649d5f2
# ╟─197f95f2-5f1a-48d8-b5d0-4d466a7650a0
# ╟─0a42c388-7ede-4e52-8dc9-ff9d34f26cb8
# ╟─01081a84-6caf-4bd1-9263-cd0bc13b9e8b
# ╠═c5e39ebb-f3a2-4f76-b015-6b0524df075a
# ╟─a689c4bc-157a-4b15-87d6-8eb50578241c
# ╠═3f387862-434c-44b8-ad9b-dbec1e7e28bd
# ╠═83b24435-e363-4ad2-abda-2eb32df3f4da
# ╟─6c76f776-65b1-45bc-bdb4-be10498c9ea0
# ╟─44077c63-3772-4196-bb08-1ce5f25407d0
# ╟─ef047bdb-8ace-4524-b345-32764dd2f9c1
# ╟─a9adf571-0c6a-4290-b7d6-8c47d959e677
# ╠═9d2256ed-4faf-494e-8746-83eb8a4bdaeb
# ╟─bda1a5a9-a8c8-48f6-bf9e-c481ed96a305
# ╟─4971e8c1-670f-454d-85d3-826912124a52
# ╟─02b9042f-ffe3-4ec4-b7af-4e362d315cb1
# ╟─3626cc10-6069-488c-a121-e3e46ef42ded
# ╠═77b67d46-c744-11ec-35f0-977442515424
# ╟─1a397e28-53ba-4a58-a40d-fba4535ae0a6
# ╠═3ac79a39-aca4-4f1f-a065-241029866dc5
# ╟─d4887776-e18f-4f69-9fbc-9661abfbb36d
# ╠═f40a2100-99a4-4c10-9b9b-2beb0efec6f9
# ╠═df058d03-8578-4b22-b59e-e8b2c2e1ce44
# ╟─16858060-1b0d-4d1f-a134-63e37ddf3a88
# ╠═28322e9b-baba-49cc-adbd-15465787dfcb
# ╠═dea77925-e281-4a0e-9825-685f47876ed4
# ╠═f2ad5416-8ed2-4c1c-951e-41b62bd7f7b4
# ╟─30943ccc-60ed-4688-84ee-4aa1e5bde97c
