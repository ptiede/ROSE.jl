import{_ as a,c as s,a5 as t,o as e}from"./chunks/framework.Dw9IRC_T.js";const c=JSON.parse('{"title":"Optimization Extension","description":"","frontmatter":{},"headers":[],"relativePath":"ext/optimization.md","filePath":"ext/optimization.md","lastUpdated":null}'),n={name:"ext/optimization.md"};function p(l,i,o,h,r,k){return e(),s("div",null,i[0]||(i[0]=[t(`<h1 id="Optimization-Extension" tabindex="-1">Optimization Extension <a class="header-anchor" href="#Optimization-Extension" aria-label="Permalink to &quot;Optimization Extension {#Optimization-Extension}&quot;">​</a></h1><p>To optimize our posterior, we use the <a href="https://github.com/SciML/Optimization.jl" target="_blank" rel="noreferrer"><code>Optimization.jl</code></a> package. Optimization provides a global interface to several Julia optimizers. The base call most people should look at is <a href="/Comrade.jl/dev/api#Comrade.comrade_opt"><code>comrade_opt</code></a> which serves as the general purpose optimization algorithm.</p><p>To see what optimizers are available and what options are available, please see the <code>Optimizations.jl</code> <a href="http://optimization.sciml.ai/dev/" target="_blank" rel="noreferrer">docs</a>.</p><h2 id="example" tabindex="-1">Example <a class="header-anchor" href="#example" aria-label="Permalink to &quot;Example&quot;">​</a></h2><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Comrade</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Optimization</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> OptimizationOptimJL</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Enzyme</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;"># Some stuff to create a posterior object</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">post </span><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;"># of type Comrade.Posterior</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">xopt, sol </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> comrade_opt</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(post, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">LBFGS</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(); adtype</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Val</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">:Enzyme</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">))</span></span></code></pre></div>`,5)]))}const m=a(n,[["render",p]]);export{c as __pageData,m as default};
