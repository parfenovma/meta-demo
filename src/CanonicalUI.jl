module CanonicalUI

using JSON
include("CanonicalData.jl")
using .CanonicalData
export CanonicalPicker, canonical_view

struct CanonicalPicker end
Base.get(::CanonicalPicker)="mass"
function Base.show(io::IO,::MIME"text/html",::CanonicalPicker)
    print(io,raw"""
    <div id="canonical-picker" style="display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;font:15px system-ui">
    <script>
    const root=document.getElementById('canonical-picker');
    const lessons=[['mass','01 · Отрицательная масса'],['bulk','02 · Отрицательный модуль'],['prism','03 · Преломление'],['absorber','04 · Поглощение'],['cloak','05 · Акустический плащ'],['focus','06 · Фокусировка STG']];
    root.value='mass';
    lessons.forEach(([id,title])=>{const b=document.createElement('button');b.type='button';b.textContent=title;b.dataset.lesson=id;b.style.cssText='font:inherit;text-align:left;padding:14px;border-radius:10px;border:1px solid #5b7887;cursor:pointer;background:transparent;color:inherit';
      b.onclick=()=>{root.value=id;root.querySelectorAll('button').forEach(q=>q.style.background=q.dataset.lesson===id?'#278d8d55':'transparent');root.dispatchEvent(new CustomEvent('input',{bubbles:true}))};root.append(b)});
    root.querySelector('button').style.background='#278d8d55';
    </script></div>""")
end

struct CanonicalHTML
    source::String
end
Base.show(io::IO,::MIME"text/html",h::CanonicalHTML)=print(io,h.source)

function canonical_view(id)
    id=ismissing(id) ? "mass" : String(id)
    data=CanonicalData.read_bundle(id)
    if id=="focus"
        # The archive retains the actual FE meshes for research/replay. The
        # viewer only needs sampled histories and outlines, not triangulations.
        for set in data["sets"], c in set["cases"]; haskey(c,"mesh") && delete!(c,"mesh"); end
    end
    # Teaching copy is separate from frozen numerical artifacts: editing an
    # explanation must not invalidate or regenerate any simulation histories.
    lessons=JSON.parsefile(joinpath(@__DIR__,"assets","canonical_lessons.json"))
    data["lessons"]=Dict("main"=>lessons[id])
    merge!(data,lessons[id]["intro"])
    if id=="cloak"
        data["lessons"]["tube"]=lessons["tube"]
        for set in data["sets"]
            set["cases"][1]["geometry"]["type"]=="tube" && merge!(set,lessons["tube"]["intro"])
        end
    end
    template=read(joinpath(@__DIR__,"assets","canonical.html"),String)
    css=read(joinpath(@__DIR__,"assets","canonical.css"),String)
    js=read(joinpath(@__DIR__,"assets","canonical.js"),String)
    payload=replace(JSON.json(data),"<"=>"\\u003c")
    CanonicalHTML(replace(template,"__CSS__"=>css,"__SCRIPT__"=>js,"__DATA__"=>payload))
end
end
