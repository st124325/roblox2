"""Typography, edit, soundtrack mastering and delivery checks, all inside CI."""
from pathlib import Path
import json
import shutil
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent
ROOT = HERE.parents[2]
B = ROOT/'build/heist'
cfg = json.loads((HERE/'config.json').read_text())
def run(*args):
    return subprocess.run(args,check=True,capture_output=True,text=True)
def ass_time(t):
    n=round(t*100);h,n=divmod(n,360000);m,n=divmod(n,6000);s,c=divmod(n,100)
    return f'{h}:{m:02}:{s:02}.{c:02}'
def srt_time(t):
    n=round(t*1000);h,n=divmod(n,3600000);m,n=divmod(n,60000);s,c=divmod(n,1000)
    return f'{h:02}:{m:02}:{s:02},{c:03}'

def captions():
    header='''[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920
WrapStyle: 0
[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Dialogue,DejaVu Sans,52,&H00FFFFFF,&H00FFFFFF,&H0012100C,&H8012100C,-1,0,0,0,100,100,0,0,1,3,1,2,110,110,320,1
Style: UI,DejaVu Sans,32,&H00DEFFAE,&H00FFFFFF,&H0012100C,&H0012100C,-1,0,0,0,100,100,2,0,1,1,0,7,0,0,0,1
Style: Title,DejaVu Sans,112,&H00FFFFFF,&H00FFFFFF,&H0012100C,&H0012100C,-1,0,0,0,100,100,-3,0,1,0,2,5,0,0,0,1
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
'''
    events=[]
    def event(start,end,style,text,layer=1):
        events.append(f'Dialogue: {layer},{ass_time(start)},{ass_time(end)},{style},,0,0,0,,{text}')
    subs=[]
    for i,line in enumerate(cfg['voice'],1):
        text=line['caption']
        if text:
            color=r'{\c&H6363FF&}' if line['key'] in ('alarm','run') else ''
            event(line['start'],line['end'],'Dialogue',r'{\fad(50,80)}'+color+text)
        subs.append(f"{i}\n{srt_time(line['start'])} --> {srt_time(line['end'])}\n{line['text']}")
    event(0.1,2.1,'UI',r'{\pos(110,230)\c&H6363FF&\fad(60,80)}BAD IDEA.')
    event(2.2,4.5,'UI',r'{\pos(110,230)}3 SECONDS EARLIER')
    event(2.2,4.5,'UI',r'{\pos(110,285)\fs26\c&HFFFFFF&}CAM 02  /  BASE OPEN')
    event(7.75,9.7,'UI',r'{\pos(110,230)\c&H6363FF&}OWNER IS BACK')
    event(14.0,16.2,'UI',r'{\pos(110,230)}SAFE... RIGHT?')
    event(18.6,22,'UI',r'{\an7\pos(0,0)\p1\c&H17100B&\alpha&H85&}m 0 0 l 1080 0 1080 1920 0 1920',0)
    event(18.7,22,'UI',r'{\an5\pos(540,360)\fs30\fad(120,0)}A ROBLOX HEIST')
    event(18.7,22,'Title',r'{\pos(540,570)\fad(120,0)}STEAL A\NMONSTER')
    event(19.0,22,'UI',r'{\an5\pos(540,1480)\fs48\fad(120,0)}TRUST NOBODY.')
    event(19.25,22,'UI',r'{\an5\pos(540,1550)\fs30\c&HFFFFFF&\fad(120,0)}PLAY ON ROBLOX')
    (B/'captions.ass').write_text(header+'\n'.join(events)+'\n')
    (B/'delivery/tiktok-heist.srt').write_text('\n\n'.join(subs)+'\n')

def preview():
    times=json.loads((B/'preview/times.json').read_text())
    for i,t in enumerate(times):
        run('ffmpeg','-y','-loglevel','error','-i',str(B/f'raw/preview-{i:02}.png'),
            '-vf',f"setpts=PTS+{t}/TB,ass={B/'captions.ass'}",'-frames:v','1',str(B/f'preview/frame-{i:02}.png'))
    sheet=Image.new('RGB',(1440,1376),'#101926')
    draw=ImageDraw.Draw(sheet)
    font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',20)
    for i,t in enumerate(times):
        im=Image.open(B/f'preview/frame-{i:02}.png').convert('RGB').resize((360,640),getattr(Image,'Resampling',Image).LANCZOS)
        x,y=(i%4)*360,(i//4)*688
        sheet.paste(im,(x,y))
        draw.text((x+14,y+652),f'{t:.1f}s',font=font,fill='white')
    sheet.save(B/'preview/storyboard.jpg',quality=92)

def final():
    (B/'concat.txt').write_text(''.join(f"file 'parts/part-{i:02}.mp4'\n" for i in range(cfg['chunks'])))
    stats=run('ffmpeg','-hide_banner','-i',str(B/'master.wav'),'-af',
        'loudnorm=I=-14:TP=-1:LRA=9:print_format=json','-f','null','-').stderr
    levels=json.loads(stats[stats.rfind('{'):])
    filt=('loudnorm=I=-14:TP=-1:LRA=9:linear=true:'
        f"measured_I={levels['input_i']}:measured_TP={levels['input_tp']}:"
        f"measured_LRA={levels['input_lra']}:measured_thresh={levels['input_thresh']}:offset={levels['target_offset']}")
    filt += ',afade=t=in:st=0:d=0.015,afade=t=out:st=21.8:d=0.2'
    out=B/'delivery/tiktok-heist.mp4'
    run('ffmpeg','-y','-f','concat','-safe','0','-i',str(B/'concat.txt'),'-i',str(B/'master.wav'),
        '-map','0:v:0','-map','1:a:0','-vf',f"setpts=N/(30*TB),ass={B/'captions.ass'}",'-r','30',
        '-c:v','libx264','-crf','18','-preset','medium','-pix_fmt','yuv420p','-af',filt,
        '-c:a','aac','-b:a','192k','-ar','48000','-movflags','+faststart','-t',str(cfg['seconds']),str(out))
    data=json.loads(run('ffprobe','-v','error','-count_frames','-show_format','-show_streams','-of','json',str(out)).stdout)
    video=next(s for s in data['streams'] if s['codec_type']=='video')
    audio=next(s for s in data['streams'] if s['codec_type']=='audio')
    assert video['avg_frame_rate']=='30/1' and int(video['nb_read_frames'])==660,video
    assert (video['width'],video['height'])==(1080,1920),video
    assert audio['codec_name']=='aac' and audio['sample_rate']=='48000',audio
    assert abs(float(data['format']['duration'])-22)<0.05,data
    (B/'delivery/validation.json').write_text(json.dumps(data,indent=2))
    shutil.copy(B/'preview/storyboard.jpg',B/'delivery/tiktok-heist-storyboard.jpg')
    shutil.copy(B/'preview/frame-00.png',B/'delivery/tiktok-heist-cover.png')
    (B/'delivery/HEIST-VIDEO.md').write_text('# Steal a Monster — The worst heist\n\n'
        '22-second original mini-story: theft, chase, false victory, betrayal. '
        '1080×1920 / 30 fps / H.264 + AAC. American English voices, original music and SFX, burned-in English dialogue.\n\n'
        'Download `tiktok-heist.mp4`. Supporting files: `tiktok-heist.srt`, `tiktok-heist-cover.png`, `tiktok-heist-storyboard.jpg`.\n\n'
        'All audio, 3D frames, typography and mastering were generated on GitHub Actions. '
        'This is staged promotional animation using a monster asset from the game, not captured gameplay.\n\n'
        'Caption: His base was open. My friend was the real problem. #Roblox #StealAMonster\n\n'
        'Assets: Quaternius Ultimate Monsters, CC0; block characters and environment created for this trailer. '
        'Voice: Piper en_US Joe medium, CC0. DejaVu Sans typography uses the system DejaVu font license. '
        'Music and effects are synthesized by tools/video/heist/prepare.py.\n')
    print('VERIFIED:',video['nb_read_frames'],'frames,',data['format']['duration'],'seconds')

{'captions':captions,'preview':preview,'final':final}[sys.argv[1]]()
