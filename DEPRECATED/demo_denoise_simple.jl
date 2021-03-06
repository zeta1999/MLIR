using FITSIO;
using PyPlot;
PyPlot.show();
include("EPLLhalfQuadraticSplit.jl");

# read in true image (for reference) and noisy image (= data from which we reconstruct)
true_image = rotl90(read((FITS("2004true137.fits"))[1])); #rotl90 to get same orientation as IDL
noiseSD = 80/255;
noisy_image = true_image + noiseSD*randn(size(true_image));
#f = FITS("2004noisy.fits", "w");
#write(f, noisy_image);close(f);
#noisy_image = read((FITS("2004noisy.fits"))[1]);
#Array{Float64,2}(read((FITS("160068_noisy.fits"))[1])');
# load the machine-learned dictionary and setup corresponding patch size

GDict = importGMM("GMM_YSO.mat");
patchSize = Int(sqrt(GDict.dim));
#setup the regularization step for ADMM
MAPGMM = (Z,patchSize,noiseSD,imsize)->aprxMAPGMM(Z,patchSize,noiseSD,imsize,GDict);
figure(1);imshow(true_image, ColorMap("gray"));PyPlot.draw();PyPlot.pause(0.05);
figure(2);imshow(noisy_image, ColorMap("gray"));PyPlot.draw();PyPlot.pause(0.05);
println("Reconstruction with patchsize= ", patchSize, " and nmodels= ", GDict.nmodels);
tic();
reconstructed_image = EPLLhalfQuadraticSplit(noisy_image,patchSize^2/noiseSD^2,patchSize, (1/noiseSD^2.0)*[1 4 8 16 32 64 128 256 512 1024 2048 4000 8000 20000 40000 80000 160000 320000],1, MAPGMM, true_image);
toc();

println("PSNR: ",20*log10(1/std(reconstructed_image-true_image)), "\n");
println("EPLL: ", EPLL(reconstructed_image, GDict), "\n");
println("l1dist: ", sum(abs(reconstructed_image-true_image))/length(true_image), "\n");
figure(3);imshow(reconstructed_image, ColorMap("gray"));PyPlot.draw();PyPlot.pause(0.05);

using Lbfgsb
# gradient method
function denoise_fg(x, g, data, noiseSD, GDict)
mu=2.;
chi2_f = sum((x-data).^2)/(noiseSD^2 * length(x));
chi2_g = (x-data)/(0.5*noiseSD^2 * length(x));
nx = Int(sqrt(length(x)));
reg_g = zeros(Float64, (nx, nx));
reg_f = EPLL_fg(reshape(x, (nx,nx)), reg_g, GDict);
g[:] = chi2_g + mu*vec(reg_g);
println("Chi2 = ", chi2_f, " EPLL =", reg_f);
imshow(reshape(x, (nx, nx)), ColorMap("gray"));PyPlot.draw();
return chi2_f + mu*reg_f
end

xstart= vec(noisy_image);
data  = vec(noisy_image);
g = zeros(size(xstart));
#denoise_fg(vec(noisy_image), g, data, noiseSD, GDict);
#denoise_fg(vec(true_image), g, data, noiseSD, GDict);
#denoise_fg(vec(reconstructed_image), g, data, noiseSD, GDict);

crit = (x,g)->denoise_fg(x, g, data, noiseSD, GDict);

xstart = vec(noisy_image);

f, x, numCall, numIter, status = lbfgsb( crit, rand(size(xstart)), lb=zeros(length(xstart)), ub=ones(length(xstart)), iprint=1);

figure(4);imshow(reshape(x, size(noisy_image)), ColorMap("gray"));PyPlot.draw();PyPlot.pause(0.05);


readline();
