x1 = [-11.323826  , -11.805944  , -12.311457  , -12.786005  ,
	-13.235448  , -13.68692   , -14.061259  , -14.481368  ,
	-14.854713  , -15.243543  , -15.628698  , -16.001549  ,
	-16.359833  , -16.692902  , -17.055052  , -17.352232  ,
	-17.618752  , -17.941965  , -18.090542  , -18.371489  ,
	-18.66091   , -18.809418  , -19.012735  , -19.22571   ,
	-19.3386    , -19.5334    , -19.666296  , -19.782993  ,
	-19.883913  , -19.915554  , -20.021574  , -20.098808  ,
	-20.158903  ]

x2 = [ 13.036427  ,  12.813602  ,  12.65787   ,  12.457138  ,
	12.304104  ,  12.122104  ,  11.878886  ,  11.7497015 ,
	11.545181  ,  11.422032  ,  11.27276   ,  11.172734  ,
	11.061014  ,  10.913866  ,  10.769809  ,  10.695907  ,
	10.565372  ,  10.497584  ,  10.342022  ,  10.2568245 ,
	10.196027  ,  10.081881  ,  10.014472  ,   9.982943  ,
	9.892901  ,   9.85651   ,   9.796701  ,   9.722107  ,
	9.685252  ,   9.664324  ,   9.637678  ,   9.630212  ,
	9.603164  ]

x3 = [-19.228607  , -18.979525  , -18.838688  , -18.610466  ,
	-18.453556  , -18.28361   , -18.012587  , -17.832355  ,
	-17.663923  , -17.51904   , -17.382696  , -17.27248   ,
	-17.184896  , -17.03507   , -16.92203   , -16.822725  ,
	-16.678505  , -16.624014  , -16.378624  , -16.350443  ,
	-16.300114  , -16.162956  , -16.103428  , -16.059347  ,
	-15.953509  , -15.925749  , -15.878131  , -15.7825575 ,
	-15.7542715 , -15.690897  , -15.668116  , -15.687647  ,
	-15.648276  ]

q1 = [  0.94114554,   0.94114554,   0.94114554,   0.94114554,
	0.94114554,   0.94114554,   0.94114554,   0.94114554,
	0.94114554,   0.94114554,   0.94114554,   0.94114554,
	0.94114554,   0.94114554,   0.94114554,   0.94114554,
	0.94114554,   0.94114554,   0.94114554,   0.94114554,
	0.94114554,   0.94114554,   0.94114554,   0.94114554,
	0.94114554,   0.94114554,   0.94114554,   0.94114554,
	0.94114554,   0.94114554,   0.94114554,   0.94114554,
	0.94114554]

q2 = [  0.15183479,   0.15183479,   0.15183479,   0.15183479,
	0.15183479,   0.15183479,   0.15183479,   0.15183479,
	0.15183479,   0.15183479,   0.15183479,   0.15183479,
	0.15183479,   0.15183479,   0.15183479,   0.15183479,
	0.15183479,   0.15183479,   0.15183479,   0.15183479,
	0.15183479,   0.15183479,   0.15183479,   0.15183479,
	0.15183479,   0.15183479,   0.15183479,   0.15183479,
	0.15183479,   0.15183479,   0.15183479,   0.15183479,
	0.15183479]

q3 = [ -0.2114974 ,  -0.2114974 ,  -0.2114974 ,  -0.2114974 ,
	-0.2114974 ,  -0.2114974 ,  -0.2114974 ,  -0.2114974 ,
	-0.2114974 ,  -0.2114974 ,  -0.2114974 ,  -0.2114974 ,
	-0.2114974 ,  -0.2114974 ,  -0.2114974 ,  -0.2114974 ,
	-0.2114974 ,  -0.2114974 ,  -0.2114974 ,  -0.2114974 ,
	-0.2114974 ,  -0.2114974 ,  -0.2114974 ,  -0.2114974 ,
	-0.2114974 ,  -0.2114974 ,  -0.2114974 ,  -0.2114974 ,
	-0.2114974 ,  -0.2114974 ,  -0.2114974 ,  -0.2114974 ,
	-0.2114974 ]

q4 = [ -0.21554607,  -0.21554607,  -0.21554607,  -0.21554607,
	-0.21554607,  -0.21554607,  -0.21554607,  -0.21554607,
	-0.21554607,  -0.21554607,  -0.21554607,  -0.21554607,
	-0.21554607,  -0.21554607,  -0.21554607,  -0.21554607,
	-0.21554607,  -0.21554607,  -0.21554607,  -0.21554607,
	-0.21554607,  -0.21554607,  -0.21554607,  -0.21554607,
	-0.21554607,  -0.21554607,  -0.21554607,  -0.21554607,
	-0.21554607,  -0.21554607,  -0.21554607,  -0.21554607,
	-0.21554607]
N = 33
X = [[x1[i], x2[i], x3[i]] for i = 1:33]
Q = [Quaternion(q1[i], q2[i], q3[i], q4[i]) for i = 1:33]