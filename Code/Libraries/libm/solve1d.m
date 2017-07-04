% Routine to find a zero of a univariate function
% Assumption: evaluation of func is costly, so overhead doesn't matter
%   what counts is to find root with minimal number of function evaluations!
% Inputs:
%   func:    handle to function
%   x0:      initial guess         
%   opt:     can be either
%            1) option structure, generated by makeopt('solve1d')
%            2) 2-element vector, giving interval in which to look for a root
%   additional arguments will be passed on to function
% Outputs:
%   x: estimate of root
%   f: function value at x
%   check: 0 if successful
% Michael Reiter, UPF, January 2006
function [x,f,check] = solve1d(func,x0,opt,varargin)

  if(nargin<3| isempty(opt))
    opt = makeopt('solve1d');
  elseif(~isstruct(opt))  %opt gives bounds
    bb = opt;
    opt = makeopt('solve1d');
    opt.bounds = bb;
  end;

  check=1;  %default: failure;
  x = x0;

  % bracket, incase newton fails
  bracket = [];
  
  % initial guess for bounds;
  if(isempty(opt.bounds))
    opt.bounds = [-1e100;1e100];
  end;
  
  step = max(1e-5*abs(x),1e-7);
  f = feval(func,x,varargin{:});
  % record all steps:
  if(isempty(opt.ftol))
    opt.ftol = 1e-8*min(max(abs(f),1),100);
  end;
  if(isempty(opt.xtol))
    opt.xtol = 1e-8*max(1,abs(x));
  end;
  if(abs(f)<opt.ftol)
    fopt = f;
    xopt = x;
    check=0;
    return;
  end;
  if(f>=1e100)
    error('inadmissible initial value in solve1d');
  end
  x2= x+step;
  f2 = feval(func,x2,varargin{:});
  if(f2>=1e100)
    error('inadmissible initial value at diff. in solve1d');
  end;
%  X = [x2;x];
%  F = [f2;f];
  X = [x];
  F = [f];

  %collect information for bracketing:
  if(f*f2<=0)
    bracket = makebracket([x,x2],[f,f2]);
  else
    if(abs(f2)<abs(f))
      direct_brak = 1;  %guess about where to bracket!
    else
      direct_brak = -1;
    end
  end;
  deriv = (f2-f) / (x2-x);

  % first try derivative step:
  donewton = 1;

  for iter=1:1000
    done = 0;
    if(deriv==0)
      donewton=0;
    end;

    if(donewton)
      step = -f/deriv;
      if(length(X)>2)
	x0 = estroot_poly(X(end-2:end),F(end-2:end));
        if(~isempty(x0))
	  step2 = x0-x;
	  test = step2/step;
	  if(test>0)  % same sign; otherwise_ keep step;
	    if(test<10)
	      step = step2;
	    else
	      step = 10*step;
	    end;
	  end;
	end;
      end;
      [x2,f2,opt.bounds,iflag,bracktry] = diffstep(func,x,f,opt.bounds,step,varargin{:});
      if(~isempty(bracktry) &(isempty(bracket) | diff(bracket.x)>diff(bracket.x)) )
	bracket = bracktry;
      end;
      if(iflag==0)
	deriv = (f2-f)/(x2-x);
	f = f2;
	x = x2;
	X = [X;x];
	F = [F;f];
      else
	donewton=0;
      end;
    else % do bisection
      if(isempty(bracket))
	step =  direct_brak*0.1*max(abs(x),1);
	bracket = findbracket2(func,x,f,step,opt.bounds,varargin{:});
	if(isempty(bracket))
	  error('could not bracket');
	end;
%	if(isempty(bracket))
%	  bracket = findbracket(func,x,f,-step,varargin{:})
%	end;
      end;
      x = mean(bracket.x);
      f = feval(func,x,varargin{:});
      [donewton,deriv] = close_linear(x,f,bracket);
      bracket = updatebracket(bracket,x,f);
      if(diff(bracket.x)<opt.xtol)
	check=0;
	return;
      end;
    end;
    if(abs(f)<=opt.ftol)
      check=0;
      return;
    end;
      
  end;
    

function [x,f,bounds,iflag,bracket] = diffstep(func,x,f,bounds,step,varargin)
  bracket = [];
  iflag = 1;  %default: fail
  f2 = 1e100;
  alambda = 1;
  x2 = x+step;
  if(x2>=bounds(2))
    alambda = 0.99*(bounds(2)-x)/step;
  elseif(x2<=bounds(1))
    alambda = 0.99*(bounds(1)-x)/step;
  end;
  while(~(abs(f2)<abs(f)) & alambda>=5e-7)
    x2 = x + alambda*step;
    f2 = feval(func,x2,varargin{:});
    if(f*f2<=0)  %different sign
      bracket = makebracket([x,x2],[f,f2]);
    end;
    if(~(f2<1e100))
      if(x2>x)
	bounds(2) = min(bounds(2),x2);
      else
	bounds(1) = max(bounds(1),x2);
      end;
    end;
    alambda = alambda / 10;
  end;
  if(abs(f2)<abs(f))
    f = f2;
    x = x2;
    iflag = 0;  % success;
  end;

  
function brack = findbracket(func,x,f,step,varargin)
  brack = [];  %failure;
  f2 = 2*f;
  for i=1:1000
    x2 = x+step;
    f2 = feval(func,x2,varargin{:});
    if(f*f2<=0)
      brack = makebracket([x,x2],[f,f2]);
      return;
    else
      x = x2;
      f = f2;
      step = step*2;
    end;
  end;
  
function br = makebracket(x,f)
  if(x(2)>x(1))
    br.x = x;
    br.f = f;
  else
    br.x = [x(2) x(1)];
    br.f = [f(2) f(1)];
  end;	 

function b2 = updatebracket(b,x,f)
  if(b.f(1)*f<=0)
    b2 = makebracket([b.x(1) x],[b.f(1) f]);
  else
    b2 = makebracket([x b.x(2)],[f b.f(1)]);
  end;	 

function [isclose,deriv] = close_linear(x,f,br)
  dmean = diff(br.f)/diff(br.x);
  ds = (f-br.f(:)) ./ (x-br.x(:));
  if(any(abs(ds-dmean)<0.2*abs(dmean)))
    % disp('yes!!');
    isclose = 1;
    deriv = dmean;
  else
    isclose = 0;
    deriv = 0;
  end;


function brack = findbracket2(func,x0,f0,step0,bounds,varargin)
  brack = [];  %failure;
  ee = ones(2,1);
  x = ee*x0;
  x2 = x;
  f = ee*f0;
  step = [step0;-step0];
  d = 1;  %first direction is step;
  for i=1:100
    if(all(x2==bounds))
      break;
    end;
    x2(d) = x(d)+step(d);
    x2(d) = min(max(x2(d),bounds(1)),bounds(2));
    f2(d) = feval(func,x2(d),varargin{:});
    if(f(d)*f2(d)<=0)
      brack = makebracket([x(d),x2(d)],[f(d),f2(d)]);
      return;
    else
      x(d) = x2(d);
      f(d) = f2(d);
      step(d) = step(d)*2;
    end;
    if(abs(f2(d))>=abs(f(d)))
      d = 3-d;  %change direction;
    end;
    if(any(x2(d)==bounds))
      d = 3-d;
    end;
  end;
  
function x0 = estroot_poly(xx,y)
  meanx = mean(xx);
  x = xx-meanx;
  sx = 1/mean(abs(x));
  x = x*sx;

  c = polyfit(x,y,length(x)-1);
  r = roots(c);
  ii = imag(r)==0;
  if(isempty(ii))
    x0 = [];
  else
    r = r(ii)/sx + meanx;
    dist = abs(r-xx(end));
    [dum,ibest] = min(dist);
    x0 = r(ibest);
  end;