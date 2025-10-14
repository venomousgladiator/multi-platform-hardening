from fpdf import FPDF
import datetime

class PDF(FPDF):
    def header(self):
        self.set_font('Arial', 'B', 12)
        self.cell(0, 10, 'System Hardening Report', 0, 1, 'C')
        self.ln(10)

    def footer(self):
        self.set_y(-15)
        self.set_font('Arial', 'I', 8)
        self.cell(0, 10, f'Page {self.page_no()}', 0, 0, 'C')

def generate_report(audit_results):
    pdf = PDF()
    pdf.add_page()
    pdf.set_font('Arial', 'B', 14)
    pdf.cell(0, 10, f"Scan completed on: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", 0, 1)
    pdf.ln(5)

    for result in audit_results:
        # Determine color and severity based on status
        if result['status'] == 'Compliant':
            pdf.set_text_color(0, 128, 0) # Green
            severity = "Low"
        elif result['status'] == 'Failure':
            pdf.set_text_color(255, 0, 0) # Red
            severity = "High"
        else:
            pdf.set_text_color(0, 0, 0) # Black
            severity = "Info"

        pdf.set_font('Arial', 'B', 10)
        pdf.multi_cell(0, 5, f"Policy: {result['parameter']}")
        pdf.set_font('Arial', '', 10)
        pdf.multi_cell(0, 5, f"Status: {result['status']} (Severity: {severity})")
        pdf.multi_cell(0, 5, f"Details: {result['details']}")
        pdf.ln(5)

    report_name = f"Hardening_Report_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf"
    pdf.output(report_name)
    return report_name