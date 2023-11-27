using DelimitedFiles, SparseArrays

using JLD, HDF5

export read_mtx, read_gmt, read_meta, read_feature_genes

"""
     read_expr_matrix(fn, rn, cn)

Read in an expression matrix stored in `fn` where its row names are stored in `rn` and column names are stored in `cn`.
It returns (matrix, vector of row names, vector of column names) 

`read_expr_matrix(fn::AbstractString,rn::AbstractString, cn::AbstractString)`

The parameters are:
- `fn::AbstractString`: Expression matrix file path, with rows representing genes and columns representing samples, does not require column names.
- `rn::AbstractString`: Gene list file path. 
- `cn::AbstractString`: Sample name list file path. 
"""
function read_expr_matrix(fn::AbstractString,rn::AbstractString, cn::AbstractString)
	isfile(fn) || throw("File $fn does not exist.")
	isfile(rn) || throw("File $rn does not exist.")
	isfile(cn) || throw("File $cn does not exist.")
	mat = readdlm(fn)
	fea = reshape(readdlm(rn), :)
	cel = reshape(readdlm(cn), :)
	r, c = size(mat)
	r == length(fea) || throw(DimensionMismatch("`rn` does not match with`fn"))
	c == length(cel) || throw(DimensionMismatch("`cn` does not match with`fn"))
	return (mat, fea, cel)
end

#Read in 10X mtx format (MatrixMarket)
"""
	read_mtx(fn, rn, cn)

Read in the common 10X single-cell RNA expression file in the MTX format (unzipped).

# Examples
```jldoctest
julia> @time res = read_mtx("matrix.mtx", "features.tsv", "barcodes.tsv")
 62.946154 seconds (481.84 M allocations: 13.082 GiB, 3.50% gc time)
(sparse([7, 27, 31, 44, 45, 46, 49, 52, 54, 58  …  36563, 36564, 36565, 36566, 36567, 36568, 36569, 36570, 36572, 36576], [1, 1, 1, 1, 1, 1, 1, 1, 1, 1  …  5744, 5744, 5744, 5744, 5744, 5744, 5744, 5744, 5744, 5744], Int32[1, 1, 5, 1, 4, 1, 1, 1, 1, 1  …  287, 8, 239, 124, 32, 8, 145, 41, 99, 2], 36601, 5744), Any["ENSG00000243485", "ENSG00000237613", "ENSG00000186092", "ENSG00000238009", "ENSG00000239945", "ENSG00000239906", "ENSG00000241860", "ENSG00000241599", "ENSG00000286448", "ENSG00000236601"  …  "ENSG00000274175", "ENSG00000275869", "ENSG00000273554", "ENSG00000278782", "ENSG00000277761", "ENSG00000277836", "ENSG00000278633", "ENSG00000276017", "ENSG00000278817", "ENSG00000277196"], Any["AAACCCAAGAACAAGG-1", "AAACCCAAGCCTGAAG-1", "AAACCCAAGCTGAGTG-1", "AAACCCAAGTATTGCC-1", "AAACCCAGTCATGACT-1", "AAACCCATCGGAATTC-1", "AAACCCATCTGTCTCG-1", "AAACGAAAGCGGGTAT-1", "AAACGAAAGGTAGCCA-1", "AAACGAAAGTGGTGAC-1"  …  "TTTGGTTTCCACAGCG-1", "TTTGTTGCACCTCGTT-1", "TTTGTTGCAGCTGTTA-1", "TTTGTTGCATACCGTA-1", "TTTGTTGGTAGGACCA-1", "TTTGTTGGTGACAGGT-1", "TTTGTTGTCCACTTTA-1", "TTTGTTGTCCTATTGT-1", "TTTGTTGTCGCTCTAC-1", "TTTGTTGTCTCCAAGA-1"])

```

# Arguments
- `fn::AbstractString`: MTX file path .
- `rn::AbstractString`: features file path.
- `cn::AbstractString`: barcodes file path.
- ` T::Type`: Datatype in the MTX file. Default: Int32.
- `feature_col::Int`: which column is used as feature names. Default: 1 (first).
- `barcode_col::Int`: which column is used as barcode names. Default: 1 (first).

"""
function read_mtx(fn::AbstractString, rn::AbstractString, cn::AbstractString; T::Type = Int32, feature_col::Int = 2, barcode_col::Int = 1)
	isfile(fn) || throw("File $fn does not exist.")
	isfile(rn) || throw("File $rn does not exist.")
	isfile(cn) || throw("File $cn does not exist.")
	dat = readdlm(fn, T, comments = true,  comment_char = '%')
	r,c,n = dat[1,:]
	fea = readdlm(rn, '\t', comments = true,  comment_char = '%')
	bar = readdlm(cn, '\t', comments = true,  comment_char = '%')
	rf, cf = size(fea)
	rb, cb = size(bar)
	if feature_col <= cf 
		fea = fea[:, feature_col]
	else
		fea = fea[:, 1]
	end
	if barcode_col <= cf 
		bar = bar[:, barcode_col]
	else
		bar = bar[:, 1]
	end
	fea = reshape(fea, :)
	bar = reshape(bar, :)
	r == length(fea) || throw(DimensionMismatch("`rn` does not match with`fn"))
	c == length(bar) || throw(DimensionMismatch("`cn` does not match with`fn"))
	mat = spzeros(T, r, c)
	mapslices(x-> mat[x[1],x[2]] = x[3], dat[2:end,:], dims = 2)
	dat = nothing
	return (mat, fea, bar)
end

"""
    read_meta(fn, group)

Read in a meta data file with the first row assumed to be the header and the row names assumed to be the profile names (cell barcodes).
Grouping information is specified by the column with the header name of `group`. If `group` is not found, the second column will be used.
It returns the grouped profile names (vector of vectors) and group names.

# Examples
```jldoctest

julia> grp, nam = read_meta("meta.tsv", "Cluster")

julia> length(grp)
12

julia> length.(grp)
12-element Vector{Int64}:
   65
  512
 1057
  647
  654
  326
  680
  369
 1191
   46
  101
   80

julia> length(nam)
12
```

```jldoctest
read_meta(fn::AbstractString, group::AbstractString = "group"; delim::AbstractChar = '\t')
```

The parameters are:
- `fn::AbstractString`: Metadata file path, the first column sample name, the second column group information. (Default = "fn_meta.txt".
- `group::AbstractString`: Specifies the column name of the group information in metadata. (Default: "group".
- `delim::AbstractChar`: Delimiter of the metadata file. (Default: = '\t')
"""
function read_meta(fn::AbstractString, group::AbstractString = "group"; delim::AbstractChar = '\t')
	isfile(fn) || throw("File $fn does not exist.")
	meta, header = readdlm(fn, delim, header = true)
	r, c = size(meta)
	c > 1 || throw("Meta file must have at least two columns and the first column should be cell barcodes (or other-type profile names).")
	header = header[header .!= ""] # write.table in R will drop the column name for the column that stores the row names
	# length(header) == c || length(header) == c -1 || throw("Meta header does not match with the content.")
	length(header) == c || throw("Meta header does not match with the content.")
	gi = findfirst(==(group), header)
	if isnothing(gi) # if `group` is not found in the meta header, assume the second column (the first non-barcode column)
		gi = 2
	end
	gi += c - length(header)
	bar = meta[:,1]
	grp = meta[:, gi]
	nam = unique(grp)
	ind = indexin(grp, nam)
	return ([bar[ind .== i] for i in 1:length(nam)], nam, bar)
end

function read_feature(fn::AbstractString; fg_sit::Int = 1, delim::AbstractChar = '\t')
	isfile(fn) || throw("File $fn does not exist.")
	features, header = readdlm(fn, delim, header = true)
	fg_sit <= size(header)[1] || throw("The column of the feature gene is greater than the number of columns in the feature gene file $fn.")
	return features[:,fg_sit]
end



function read_marker_fea(fn::AbstractString = "marker_feas.tsv"; delim::AbstractChar = '\t')
	isfile(fn) || throw("File $fn does not exist.")
	marker_fea = readdlm(fn, delim, header = false)
	size(marker_fea)[2] >= 2 || throw("There is no gene pair information in the file $fn.")
	return marker_fea[:,1:2]
end

function load_RandomForest_classifier(fn::AbstractString = "RandomForest_classifier.jld")
	isfile(fn) || throw("File $fn does not exist.")
	classifier = collect(values(load(fn)))[1]
    return classifier
end