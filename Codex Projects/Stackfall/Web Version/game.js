(() => {
  const W = 10, H = 20;
  const pieces = [
    {name:'Cherry', fruit:'🍒', bg:'#d84564', cells:[[0,1],[1,1],[2,1],[3,1]]},
    {name:'Lemon', fruit:'🍋', bg:'#e4bc36', cells:[[1,0],[1,1],[1,2],[2,2]]},
    {name:'Grape', fruit:'🍇', bg:'#774cb7', cells:[[2,0],[1,1],[2,1],[2,2]]},
    {name:'Peach', fruit:'🍑', bg:'#ee8b72', cells:[[1,0],[2,0],[1,1],[2,1]]},
    {name:'Pear', fruit:'🍐', bg:'#7ebf52', cells:[[1,0],[2,0],[0,1],[1,1]]},
    {name:'Orange', fruit:'🍊', bg:'#ec9147', cells:[[0,0],[1,0],[1,1],[2,1]]},
    {name:'Strawberry', fruit:'🍓', bg:'#d64f57', cells:[[1,0],[0,1],[1,1],[2,1]]}
  ];
  const boardEl = document.querySelector('#board'), nextEl = document.querySelector('#nextPreview');
  const ui = Object.fromEntries(['score','lines','level','best','mobileScore','mobileLines','levelCopy','gameOverlay','overlayTitle','overlayText','startButton','soundButton'].map(id=>[id,document.getElementById(id)]));
  let board, current, next, score, lines, level, playing, timer, sound = true;
  let best = Number(localStorage.getItem('stackfall-best') || 0);
  const levelWords=['Fresh fruit. Easy pace.','A little zestier.','The orchard wakes up.','Juice is flowing.','Keep it together.','Vine-ripened speed.','The fruit flies.','No bruises allowed.','Pure pulp panic.','ORCHARD LEGEND!'];

  function randomPiece(){ const p=pieces[Math.floor(Math.random()*pieces.length)]; return {...p, cells:p.cells.map(c=>[...c])}; }
  function reset(){ board=Array.from({length:H},()=>Array(W).fill(null)); score=0; lines=0; level=1; current=null; next=randomPiece(); playing=false; clearInterval(timer); render(); updateUI(); preview(); }
  function spawn(){ current=next; next=randomPiece(); current.x=3; current.y=0; if(collides(current.cells,current.x,current.y)){ endGame(); return; } preview(); }
  function collides(cells,x,y){ return cells.some(([cx,cy])=>{ const px=x+cx,py=y+cy; return px<0||px>=W||py>=H||(py>=0&&board[py][px]); }); }
  function rotate(){ if(!playing)return; const rotated=current.cells.map(([x,y])=>[3-y,x]); for(const kick of [0,-1,1,-2,2]){if(!collides(rotated,current.x+kick,current.y)){current.cells=rotated;current.x+=kick; blip(430);render();return;}} }
  function move(dx){if(!playing)return;if(!collides(current.cells,current.x+dx,current.y)){current.x+=dx;blip(270);render();}}
  function tick(){if(!playing)return;if(!collides(current.cells,current.x,current.y+1)){current.y++;render()}else lock();}
  function hardDrop(){if(!playing)return;let distance=0;while(!collides(current.cells,current.x,current.y+1)){current.y++;distance++;}score+=distance*2;lock();blip(150);}
  function lock(){ current.cells.forEach(([x,y])=>{let px=current.x+x,py=current.y+y;if(py>=0)board[py][px]={fruit:current.fruit,bg:current.bg};}); const full=[]; board.forEach((row,y)=>{if(row.every(Boolean))full.push(y)}); if(full.length){score += [0,100,300,500,800][full.length]*level; lines += full.length; level=Math.min(10,Math.floor(lines/5)+1); flashAndClear(full); } else { spawn(); render(); updateUI(); } }
  function flashAndClear(rows){ render(rows); setTimeout(()=>{board=board.filter((_,y)=>!rows.includes(y));while(board.length<H)board.unshift(Array(W).fill(null));spawn();render();updateUI();blip(720);},280); }
  function start(){reset();playing=true;spawn();ui.gameOverlay.hidden=true;timer=setInterval(tick,Math.max(120,720-(level-1)*65));render();updateUI();}
  function endGame(){playing=false;clearInterval(timer);best=Math.max(best,score);localStorage.setItem('stackfall-best',best);ui.overlayTitle.textContent='FRUIT SPLAT!';ui.overlayText.textContent=`You scored ${score.toLocaleString()} points.`;ui.startButton.innerHTML='PLAY AGAIN <span>↻</span>';ui.gameOverlay.hidden=false;updateUI();blip(110);}
  function render(clearing=[]){ const active={};if(current){current.cells.forEach(([x,y])=>{const px=x+current.x,py=y+current.y;if(py>=0)active[`${px},${py}`]={fruit:current.fruit,bg:current.bg};});} boardEl.innerHTML='';for(let y=0;y<H;y++)for(let x=0;x<W;x++){const cell=document.createElement('div');cell.className='cell';const val=active[`${x},${y}`]||board[y][x];if(val){cell.classList.add('fruit');if(clearing.includes(y))cell.classList.add('clearing');cell.style.setProperty('--fruit-bg',`linear-gradient(145deg, ${val.bg}, color-mix(in srgb, ${val.bg}, #160b22 42%))`);const fruit=document.createElement('span');fruit.textContent=val.fruit;cell.append(fruit);}boardEl.append(cell);} }
  function preview(){nextEl.innerHTML='';const occupied=new Map(next.cells.map(([x,y])=>[`${x},${y}`,true]));for(let y=0;y<4;y++)for(let x=0;x<4;x++){const c=document.createElement('div');c.className='next-cell';if(occupied.has(`${x},${y}`))c.textContent=next.fruit;nextEl.append(c);} }
  function updateUI(){const s=String(score).padStart(6,'0');ui.score.textContent=s;ui.mobileScore.textContent=s;ui.lines.textContent=lines;ui.mobileLines.textContent=lines;ui.level.textContent=level;ui.best.textContent=best.toLocaleString();ui.levelCopy.textContent=levelWords[level-1];if(playing){clearInterval(timer);timer=setInterval(tick,Math.max(120,720-(level-1)*65));}}
  function blip(f){if(!sound||!window.AudioContext)return;try{const ctx=blip.ctx||(blip.ctx=new AudioContext());const o=ctx.createOscillator(),g=ctx.createGain();o.frequency.value=f;g.gain.setValueAtTime(.035,ctx.currentTime);g.gain.exponentialRampToValueAtTime(.001,ctx.currentTime+.09);o.connect(g).connect(ctx.destination);o.start();o.stop(ctx.currentTime+.1)}catch{}}
  document.addEventListener('keydown',e=>{if(['ArrowLeft','ArrowRight','ArrowDown','ArrowUp',' '].includes(e.key))e.preventDefault();if(e.key==='ArrowLeft')move(-1);if(e.key==='ArrowRight')move(1);if(e.key==='ArrowDown')tick();if(e.key==='ArrowUp')rotate();if(e.key===' ')hardDrop();if(e.key==='Enter'&&!playing)start();});
  [['leftButton',()=>move(-1)],['rightButton',()=>move(1)],['downButton',tick],['rotateButton',rotate],['dropButton',hardDrop]].forEach(([id,fn])=>document.getElementById(id).addEventListener('click',fn));
  ui.startButton.addEventListener('click',start);ui.soundButton.addEventListener('click',()=>{sound=!sound;ui.soundButton.textContent=sound?'♬':'×';});reset();
})();