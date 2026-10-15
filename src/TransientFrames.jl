# Display-only transport shared by solid and water transients. Numerical sensor
# histories never pass through this lossy representation.
using Base64,CodecZlib

function encode_frames(values,limit)
    isfinite(limit)&&limit>0 || throw(ArgumentError("positive finite display scale required"))
    base64encode(transcode(ZlibCompressor,
        collect(reinterpret(UInt8,htol.(round.(Int16,clamp.(vec(values)./limit,-1,1).*32767))))))
end
