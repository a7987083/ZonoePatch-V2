#!/usr/bin/env python3
"""Reproducible host microbenchmarks; device scenarios explicitly remain unverified."""
import argparse,json,platform,subprocess,tempfile,os
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--output',default='performance-host.json');args=p.parse_args()
root=Path(__file__).resolve().parents[1]
compiler=os.environ.get('CXX','clang++' if platform.system()=='Darwin' else 'g++')
with tempfile.TemporaryDirectory() as d:
 binary=Path(d)/'benchmark'
 subprocess.run([compiler,'-std=c++17','-O2','-pthread','-Wall','-Wextra','-Werror','-I'+str(root/'iosruntimepatchmenu/src'),str(root/'iosruntimepatchmenu/tests/macho_benchmark.cpp'),'-o',str(binary)],check=True)
 lines=subprocess.check_output([str(binary)],text=True).splitlines()
results=[dict(scenario=n,medianNs=int(m),p95Ns=int(q)) for n,m,q in (line.split(',') for line in lines)]
report=dict(schema='zonoe.host-microbenchmark/v1',commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),environment=dict(platform=platform.platform(),machine=platform.machine(),compiler=subprocess.check_output([compiler,'--version'],text=True).splitlines()[0]),protocol=dict(warmupBatches=5,measuredBatches=31,iterationsPerBatch=1000,fixtureBytes=65536,clock='steady_clock',build='-O2',scope='portable production parser/editor microbenchmark; not UIKit/target App'),results=results,deviceScenarios={k:'未验证' for k in ['menu.activation','page.refresh','search.sync','hook.reconcile.execution','binary.generation']},performanceImprovement='未验证：无匹配基线/实机数据')
Path(args.output).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False,indent=2))
