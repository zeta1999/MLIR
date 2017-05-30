#using NFFT
# NFFT
#plan = NFFTPlan(full_uv*scale_rad, (nx,nx));
#for n in 1:nw
#  cvis_model[:,n] = nfft(plan, image + 0. * im);
#end

#DFT -- warning, centering is different from NFFT
#xtransform = zeros(Complex{Float64},nuv, nx)
#ytransform = zeros(Complex{Float64},nuv, nx)
#for uu=1:nuv
# xtransform and ytransform use less memory than the full dft
# but the dft can take bandwidth smearing into account better
#    xtransform[uu, :] = exp(2 * pi * im * scale_rad * v2_u[uu] * [i for i=1:nx]); # could be  (ii - (nx+1) / 2) for centering
#    ytransform[uu, :] = exp(2 * pi * im * scale_rad * v2_v[uu] * [i for i=1:nx]);
#end

function setup_ft(data, nx, pixsize)
scale_rad = pixsize * (pi / 180.0) / 3600000.0;
dft = zeros(Complex{Float64}, data.nuv, nx*nx);
xvals = [((i-1)%nx+1) for i=1:nx*nx];
yvals=  [(div(i-1,nx)+1) for i=1:nx*nx];
for uu=1:data.nuv
    dft[uu,:] = exp(-2 * pi * im * scale_rad * (data.uv[1,uu] * xvals + data.uv[2,uu] * yvals));
end
return dft
end

function mod360(x)
mod(mod(x+180,360.)+360., 360.) - 180.
end

function cvis_to_v2(cvis, indx)
  v2_model = abs2(cvis[indx]);
end

function cvis_to_t3(cvis, indx1, indx2, indx3)
  t3 = cvis[indx1].*cvis[indx2].*cvis[indx3];
  t3amp = abs(t3);
  t3phi = angle(t3)*180./pi;
  return t3, t3amp, t3phi
end

#fig = figure("Image",figsize=(10,10));imshow(rotl90(image));PyPlot.draw();PyPlot.pause(1);

function image_to_cvis(x, dft)
  flux = sum(x);
  nuv = size(dft, 1)
  cvis_model = zeros(Complex{Float64},data.nuv);
  cvis_model = dft * x / flux;
end


function chi2(x, dft, data, verbose = true)
cvis_model = image_to_cvis(x, dft);
# compute observables from all cvis
v2_model = cvis_to_v2(cvis_model, data.indx_v2);
t3_model, t3amp_model, t3phi_model = cvis_to_t3(cvis_model, data.indx_t3_1, data.indx_t3_2 ,data.indx_t3_3);
chi2_v2 = sum( ((v2_model - data.v2_data)./data.v2_data_err).^2);
chi2_t3amp = sum( ((t3amp_model - data.t3amp_data)./data.t3amp_data_err).^2);
chi2_t3phi = sum( (mod360(t3phi_model - data.t3phi_data)./data.t3phi_data_err).^2);
if verbose == true
  flux = sum(x);
  println("V2: ", chi2_v2, " T3A: ", chi2_t3amp, " T3P: ", chi2_t3phi," Flux: ", flux)
  println("chi2V2: ", chi2_v2/data.nv2, " chi2T3A: ", chi2_t3amp/data.nt3amp, " chi2T3P: ", chi2_t3phi/data.nt3phi," Flux: ", flux)
end
return chi2_v2 + chi2_t3amp + chi2_t3phi
end

function chi2_fg(x, g, dft, data ) # criterion function plus its gradient w/r x
#nx2 = length(x);
cvis_model = image_to_cvis(x, dft);
# compute observables from all cvis
v2_model = cvis_to_v2(cvis_model, data.indx_v2);
t3_model, t3amp_model, t3phi_model = cvis_to_t3(cvis_model, data.indx_t3_1, data.indx_t3_2 ,data.indx_t3_3);
chi2_v2 = sum( ((v2_model - data.v2_data)./data.v2_data_err).^2);
chi2_t3amp = sum( ((t3amp_model - data.t3amp_data)./data.t3amp_data_err).^2);
chi2_t3phi = sum( (mod360(t3phi_model - data.t3phi_data)./data.t3phi_data_err).^2);
tic();
g_v2 = 4.0*sum(((v2_model-data.v2_data)./data.v2_data_err.^2).*real(conj(cvis_model[data.indx_v2]).*dft[data.indx_v2,:]),1);
g_t3amp = 2.0*sum(((t3amp_model-data.t3amp_data)./data.t3amp_data_err.^2).*
                  (   real( conj(cvis_model[data.indx_t3_1]./abs(cvis_model[data.indx_t3_1])).*dft[data.indx_t3_1,:]).*abs(cvis_model[data.indx_t3_2]).*abs(cvis_model[data.indx_t3_3])       + real( conj(cvis_model[data.indx_t3_2]./abs(cvis_model[data.indx_t3_2])).*dft[data.indx_t3_2,:]).*abs(cvis_model[data.indx_t3_1]).*abs(cvis_model[data.indx_t3_3])+ real( conj(cvis_model[data.indx_t3_3]./abs(cvis_model[data.indx_t3_3])).*dft[data.indx_t3_3,:]).*abs(cvis_model[data.indx_t3_1]).*abs(cvis_model[data.indx_t3_2])),1);

t3model_der = dft[data.indx_t3_1,:].*cvis_model[data.indx_t3_2].*cvis_model[data.indx_t3_3] + dft[data.indx_t3_2,:].*cvis_model[data.indx_t3_1].*cvis_model[data.indx_t3_3] + dft[data.indx_t3_3,:].*cvis_model[data.indx_t3_1].*cvis_model[data.indx_t3_2];
g_t3phi =360./pi*sum(((mod360(t3phi_model-data.t3phi_data)./data.t3phi_data_err.^2)./abs2(t3_model)).*(-imag(t3_model).*real(t3model_der)+real(t3_model).*imag(t3model_der)),1);
toc();
imdisp(x);
g[:] = squeeze(g_v2 + g_t3amp + g_t3phi,1);
flux = sum(x);
g[:] = (g - sum(x.*g) / flux ) / flux; # gradient correction to take into account the non-normalized image
println("V2: ", chi2_v2/data.nv2, " T3A: ", chi2_t3amp/data.nt3amp, " T3P: ", chi2_t3phi/data.nt3phi," Flux: ", flux)
return chi2_v2 + chi2_t3amp + chi2_t3phi
end

function gaussian2d(n,m,sigma)
g2d = [exp(-((X-(m/2)).^2+(Y-n/2).^2)/(2*sigma.^2)) for X=1:m, Y=1:n]
return g2d
end

function cdg(x) #note: this takes a 2D array
xvals=[i for i=1:size(x,1)]
return [sum(xvals'*x) sum(x*xvals)]/sum(x)
end

function reg_centering(x,g) # takes a 1D array
nx = Int(sqrt(length(x)))
flux= sum(x)
c = cdg(reshape(x,nx,nx))
f = (c[1]-(nx+1)/2)^2+(c[2]-(nx+1)/2)^2
xx = [mod(i-1,nx)+1 for i=1:nx*nx]
yy = [div(i-1,nx)+1 for i=1:nx*nx]
g[1:nx*nx] = 2*(c[1]-(nx+1)/2)*xx + 2*(c[2]-(nx+1)/2)*yy
g[1:nx*nx] = (g - sum(x.*g) / flux ) / flux;
return f
end

function crit_fgreg(x, g, dft, data) # criterion with regularization
nx2 = length(x)
flux = sum(x);
cvis_model = zeros(Complex{Float64},div(data.nuv,data.nw),data.nw);
cvis_model[:,1] = dft * x / flux;
# compute observables from all cvis
v2_model = cvis_to_v2(cvis_model, data.indx_v2);
t3_model, t3amp_model, t3phi_model = cvis_to_t3(cvis_model, data.indx_t3_1, data.indx_t3_2 ,data.indx_t3_3);
chi2_v2 = sum( ((v2_model - data.v2_data)./data.v2_data_err).^2);
chi2_t3amp = sum( ((t3amp_model - data.t3amp_data)./data.t3amp_data_err).^2);
chi2_t3phi = sum( (mod360(t3phi_model - data.t3phi_data)./data.t3phi_data_err).^2);
rho = 1e5
reg_der = zeros(size(x))
reg = reg_centering(x, reg_der)
# note: this is correct but slower
tic();
g_v2 = 4.0*sum(((v2_model-data.v2_data)./data.v2_data_err.^2).*real(conj(cvis_model[data.indx_v2]).*dft[data.indx_v2,:]),1);
g_t3amp = 2.0*sum(((t3amp_model-data.t3amp_data)./data.t3amp_data_err.^2).*
                  (   real( conj(cvis_model[data.indx_t3_1]./abs(cvis_model[data.indx_t3_1])).*dft[data.indx_t3_1,:]).*abs(cvis_model[data.indx_t3_2]).*abs(cvis_model[data.indx_t3_3])       + real( conj(cvis_model[data.indx_t3_2]./abs(cvis_model[data.indx_t3_2])).*dft[data.indx_t3_2,:]).*abs(cvis_model[data.indx_t3_1]).*abs(cvis_model[data.indx_t3_3])+ real( conj(cvis_model[data.indx_t3_3]./abs(cvis_model[data.indx_t3_3])).*dft[data.indx_t3_3,:]).*abs(cvis_model[data.indx_t3_1]).*abs(cvis_model[data.indx_t3_2])),1);

t3model_der = dft[data.indx_t3_1,:].*cvis_model[data.indx_t3_2].*cvis_model[data.indx_t3_3] + dft[data.indx_t3_2,:].*cvis_model[data.indx_t3_1].*cvis_model[data.indx_t3_3] + dft[data.indx_t3_3,:].*cvis_model[data.indx_t3_1].*cvis_model[data.indx_t3_2];

g_t3phi =360./pi*sum(((mod360(t3phi_model-data.t3phi_data)./data.t3phi_data_err.^2)./abs2(t3_model)).*(-imag(t3_model).*real(t3model_der)+real(t3_model).*imag(t3model_der)),1);
toc();
imdisp(x)
g[1:end] = squeeze(g_v2 + g_t3amp + g_t3phi,1) +  rho * reg_der;
g[1:end] = (g - sum(x.*g) / flux ) / flux; # gradient correction to take into account the non-normalized image
println("V2: ", chi2_v2/data.nv2, " T3A: ", chi2_t3amp/data.nt3amp, " T3P: ", chi2_t3phi/data.nt3phi," Flux: ", flux, " CDG ", cdg(reshape(x,nx,nx)))
return chi2_v2 + chi2_t3amp + chi2_t3phi + rho *reg
end


function fdata_admm(z, g, dft, data, alpha, zt) # criterion with regularization
nx2 = length(z)
flux = sum(z);
cvis_model = zeros(Complex{Float64},div(data.nuv,data.nw),data.nw);
cvis_model[:,1] = dft * z / flux;
# compute observables from all cvis
v2_model = cvis_to_v2(cvis_model, data.indx_v2);
t3_model, t3amp_model, t3phi_model = cvis_to_t3(cvis_model, data.indx_t3_1, data.indx_t3_2 ,data.indx_t3_3);
chi2_v2 = sum( ((v2_model - data.v2_data)./data.v2_data_err).^2);
chi2_t3amp = sum( ((t3amp_model - data.t3amp_data)./data.t3amp_data_err).^2);
chi2_t3phi = sum( (mod360(t3phi_model - data.t3phi_data)./data.t3phi_data_err).^2);
reg = 0.5*alpha*sum((z-zt).^2);
reg_der = alpha*sum(z-zt);
# note: this is correct but slower

g_v2 = 4.0*sum(((v2_model-data.v2_data)./data.v2_data_err.^2).*real(conj(cvis_model[data.indx_v2]).*dft[data.indx_v2,:]),1);
g_t3amp = 2.0*sum(((t3amp_model-data.t3amp_data)./data.t3amp_data_err.^2).*
                  (   real( conj(cvis_model[data.indx_t3_1]./abs(cvis_model[data.indx_t3_1])).*dft[data.indx_t3_1,:]).*abs(cvis_model[data.indx_t3_2]).*abs(cvis_model[data.indx_t3_3])       + real( conj(cvis_model[data.indx_t3_2]./abs(cvis_model[data.indx_t3_2])).*dft[data.indx_t3_2,:]).*abs(cvis_model[data.indx_t3_1]).*abs(cvis_model[data.indx_t3_3])+ real( conj(cvis_model[data.indx_t3_3]./abs(cvis_model[data.indx_t3_3])).*dft[data.indx_t3_3,:]).*abs(cvis_model[data.indx_t3_1]).*abs(cvis_model[data.indx_t3_2])),1);

t3model_der = dft[data.indx_t3_1,:].*cvis_model[data.indx_t3_2].*cvis_model[data.indx_t3_3] + dft[data.indx_t3_2,:].*cvis_model[data.indx_t3_1].*cvis_model[data.indx_t3_3] + dft[data.indx_t3_3,:].*cvis_model[data.indx_t3_1].*cvis_model[data.indx_t3_2];

g_t3phi =360./pi*sum(((mod360(t3phi_model-data.t3phi_data)./data.t3phi_data_err.^2)./abs2(t3_model)).*(-imag(t3_model).*real(t3model_der)+real(t3_model).*imag(t3model_der)),1);
imdisp(z)
g[1:end] = squeeze(g_v2 + g_t3amp + g_t3phi,1) +  reg_der;
g[1:end] = (g - sum(z.*g) / flux ) / flux; # gradient correction to take into account the non-normalized image
println("V2: ", chi2_v2/data.nv2, " T3A: ", chi2_t3amp/data.nt3amp, " T3P: ", chi2_t3phi/data.nt3phi," Flux: ", flux, " REG: ", reg);
return chi2_v2 + chi2_t3amp + chi2_t3phi + reg
end


function proj_positivity(ztilde)
z = copy(ztilde)
z[ztilde.>0]=0
return z
end