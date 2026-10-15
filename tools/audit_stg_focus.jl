# Developer-only: test full-wall focusing, with the same vector-elastic solver
# as the notebook. Never imported by the viewer.
using MetaNDT, JSON, LinearAlgebra, Serialization
import Gridap, GridapGmsh, Gmsh
BLAS.set_num_threads(1)
ext=Base.get_extension(MetaNDT,:MetaNDTGridapExt)
out=only(ARGS); mkpath(out)
cache=joinpath(out,"calibration.jls")
design=isfile(cache) ? deserialize(cache) : design_stg_lens(SolidLensExperiment())
serialize(cache,design)

function retarget(d,phase_distance)
    s=d.experiment; b=first(s.bricks); cs=last(solid_wave_speeds(s)); k=2π*s.frequency/cs
    centers=[(j-(length(s.bricks)+1)/2)*b.height for j in eachindex(s.bricks)]
    target=[-k*(hypot(phase_distance,y)-phase_distance) for y in centers]
    usable=findall(t->isfinite(abs(t))&&abs(t)>.15,d.transmission)
    best=Inf; selected=Int[]; errors=Float64[]
    for offset in range(-π,π;length=73)
        ids=[usable[argmin([abs(angle(d.transmission[i]*cis(-φ-offset)))^2+
            .04/max(abs(d.transmission[i]),.05)^2 for i in usable])] for φ in target]
        err=[angle(d.transmission[i]*cis(-φ-offset)) for (i,φ) in zip(ids,target)]
        score=sum(abs2,err)+sum(.04/max(abs(d.transmission[i]),.05)^2 for i in ids)
        if score<best;best=score;selected=ids;errors=err;end
    end
    LensDesign(remake_experiment(s;bricks=d.candidates[selected]),d.candidates,d.transmission,selected,errors)
end

function measure(r)
    x=collect(range(.025,.075;length=51)); y=collect(range(-.04,.04;length=201))
    points=[(xx,yy) for yy in y for xx in x]
    sampler=ext.sensor_sampler(r.nodes,r.triangles,reshape(1:size(r.nodes,2),1,:),points,size(r.nodes,2))
    field=reshape(abs2.(sampler*r.displacement_y),length(x),length(y))
    widths=[MetaNDT.profile_width(y,field[i,:]) for i in eachindex(x)]
    valid=findall(i->isfinite(widths[i])&&abs(y[argmax(field[i,:])])<.003,eachindex(x))
    i=valid[argmin(widths[valid])]
    (;waist_x_m=x[i],width_m=widths[i],profile_peak_y_m=y[argmax(field[i,:])],
      power_balance=r.diagnostics["power_balance_relative"],x,widths)
end

rows=Any[]
for distance in (.040,.052,.064)
    d=retarget(design,distance);serialize(joinpath(out,"design_$(round(Int,distance*1000)).jls"),d)
    r=@time simulate(d.experiment)
    m=measure(r);row=(;phase_distance_m=distance,m...)
    println(JSON.json(row));push!(rows,row)
    write(joinpath(out,"harmonic.json"),JSON.json(rows));GC.gc()
end
