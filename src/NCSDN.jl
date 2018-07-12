module NCSDN

using NCDatasets
using Missings

# import ODVspreadsheet:
#     NO_QUALITY_CONTROL,
#     GOOD_VALUE,
#     PROBABLY_GOOD_VALUE,
#     PROBABLY_BAD_VALUE,
#     BAD_VALUE,
#     CHANGED_VALUE,
#     VALUE_BELOW_DETECTION,
#     VALUE_IN_EXCESS,
#     INTERPOLATED_VALUE,
#     MISSING_VALUE,
#     VALUE_PHENOMENON_UNCERTAIN

# SeaDataNet Quality Flags
# http://vocab.nerc.ac.uk/collection/L20/current/

const NO_QUALITY_CONTROL = "0"
const GOOD_VALUE = "1"
const PROBABLY_GOOD_VALUE = "2"
const PROBABLY_BAD_VALUE = "3"
const BAD_VALUE = "4"
const CHANGED_VALUE = "5"
const VALUE_BELOW_DETECTION = "6"
const VALUE_IN_EXCESS = "7"
const INTERPOLATED_VALUE = "8"
const MISSING_VALUE = "9"
const VALUE_PHENOMENON_UNCERTAIN = "A"


const QC_SUFFIX = "SEADATANET_QC"

"""
    data = loadvar(ds,param;
                   fillvalue::T = NaN,
                   qualityflags = [GOOD_VALUE, PROBABLY_GOOD_VALUE],
                   qfname = param * QC_SUFFIX,
                   )

Load the NetCDF variable `param` from the NCDataset `ds`. 
Data points not having the provide quality flags will be masked by `fillvalue`.
`qfname` is the NetCDF variable name for the quality flags.

"""
function loadvar(ds,param;
                 fillvalue::T = NaN,
                 qualityflags = [GOOD_VALUE, PROBABLY_GOOD_VALUE],
                 qfname = param * QC_SUFFIX,
                 ) where T

    if !(param in ds)
        #@show "no data for",param
        return T[]
    end
    
    dataarray = ds[param][:]
    data = nomissing(dataarray,fillvalue)
       
    if qfname in ds
        qf = ds[qfname].var[:]

        keep_data = falses(size(qf))
        
        for flag in qualityflags
            keep_data[:] =  keep_data .| (qf .== flag[1])
        end

        data[(.!keep_data)] = fillvalue
    end

    return data
end

"""
    data,lon,lat,z,time,ids = load(T,fname::TS,param; qualityflags = [GOOD_VALUE, PROBABLY_GOOD_VALUE]) where TS <: AbstractString


"""
function load(T,fname::TS,param; qualityflags = [GOOD_VALUE, PROBABLY_GOOD_VALUE]) where TS <: AbstractString
    fillvalue = NaN
    fillvalueDT = DateTime(1000,1,1)

    #@show fname
    
    ds = Dataset(fname)
    data = loadvar(ds,param;
                   fillvalue = fillvalue,
                   qualityflags = qualityflags)

    if data == []
        return T[],T[],T[],T[],DateTime[],String[]
    end

    lon = loadvar(ds,"LONGITUDE";
                  fillvalue = fillvalue,
                  qfname = "POSITION" * QC_SUFFIX,
                  qualityflags = qualityflags)

    if ndims(lon) == 1
        #@show fname,param,size(lon),size(data)
        @assert size(lon,1) == size(data,2)
        lon = repmat(reshape(lon,1,size(lon,1)),size(data,1),1)
    end
    
    lat = loadvar(ds,"LATITUDE";
                  fillvalue = fillvalue,
                  qfname = "POSITION" * QC_SUFFIX,
                  qualityflags = qualityflags)
    if ndims(lat) == 1
        @assert size(lat,1) == size(data,2)
        lat = repmat(reshape(lat,1,size(lat,1)),size(data,1),1)
    end

    z =
        if "DEPTH" in ds
            loadvar(ds,"DEPTH";
                    fillvalue = fillvalue,
                    qualityflags = qualityflags)
        else
            # assume 1 decibar is 1 meter
            loadvar(ds,"PRES";
                    fillvalue = fillvalue,
                    qualityflags = qualityflags)
        end
    
    time = loadvar(ds,"TIME";
                   fillvalue = fillvalueDT,
                   qualityflags = qualityflags)
    #@show time
    if ndims(time) == 1
        @assert size(time,1) == size(data,2)
        time = repmat(reshape(time,1,size(time,1)),size(data,1),1)
    end

    edmo = ds["SDN_EDMO_CODE"][:]
    cdiid = ds["SDN_LOCAL_CDI_ID"][:]

    @assert size(edmo,1) == size(data,2)
    @assert size(cdiid,2) == size(data,2)

    ids = Array{String,ndims(data)}(size(data))
    for j = 1:size(data,2)
        for i = 1:size(data,1)
            ids[i,j] = "$(edmo[j])-$(join(cdiid[:,j]))"
        end
    end
            
    close(ds)

    return data,lon,lat,z,time,ids
end
    
"""
    data,lon,lat,z,time,ids = SDN.load(T,fnames,param; qualityflags = ...)

Load all data in the vector of file names `fnames` corresponding to the parameter 
`param` as the data type `T`. Only the data with the quality flags 
`SDN.good_data` and `SDN.probably_good_data` are loaded per default.
The output parameters correspondata to the data, longitude, latitude,
depth, time (as `DateTime`) and an identifier (as `String`).
"""
function load(T,fnames::Vector{TS},param;
              qualityflags = [GOOD_VALUE, PROBABLY_GOOD_VALUE]) where TS <: AbstractString
    data = T[]
    lon = T[]
    lat = T[]
    z = T[]
    time = DateTime[]
    ids = String[]
    
    for fname in fnames
        #@show fname
        data_,lon_,lat_,z_,time_,ids_ = load(T,fname,param;
                                             qualityflags = qualityflags)

        append!(data,data_[:])
        append!(lon,lon_[:])
        append!(lat,lat_[:])
        append!(z,z_[:])
        append!(time,time_[:])
        append!(ids,ids_[:])        
    end

    return data,lon,lat,z,time,ids
end




end